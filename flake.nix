{
  description = "cm5 NixOS Core";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    
    crane.url = "github:ipetkov/crane"; # nix faster cargo build tool

    deploy-rs = { # nix deploy tool
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rkbin = { # newer than nixpkgs' copy; 2-channel needs DDR init v1.20+
      url = "github:rockchip-linux/rkbin";
      flake = false;
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      deploy-rs,
      rkbin,
    }:
    let
      os = self.nixosConfigurations.core;
      # Compute modules share one system and deploy target; their images only differ in the
      # boot area: the DDR init and which dts/<name>.dts U-Boot boots.
      computeModulesList = {
        radxa-cm5.hardware.rk3588.fdtfile = "radxa-cm5.dtb";
        cm-rk3588.hardware.rk3588 = {
          fdtfile = "cm-rk3588.dtb";
          ddrSettings."channel mask" = 3; # single x32 chip on CH0
        };
      };
    in
    {
      nixosConfigurations.core = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit crane rkbin; };
        modules = [ ./configuration.nix ];
      };

      packages.aarch64-linux = nixpkgs.lib.concatMapAttrs (
        name: computeModule:
        let
          build = (os.extendModules { modules = [ computeModule ]; }).config.system.build;
        in
        {
          "image-${name}" = build.sdImage;
          "loader-${name}" = build.maskromLoader;
        }
      ) computeModulesList;
      # Same outputs on the Mac, so `nix build .#<name>` works there (built on the Linux builder).
      packages.aarch64-darwin = self.packages.aarch64-linux;

      # deploy-rs device access configuration
      deploy.nodes.cm5 = {
        hostname = ""; # no default; deploy with --hostname <host-or-ip>
        sshUser = "deploy";
        user = "root"; # through sudo; defaults to sshUser, which can't switch the system
        profiles.system.path = deploy-rs.lib.aarch64-linux.activate.nixos os;
      };
    };
}
