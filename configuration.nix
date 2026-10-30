{ config, lib, pkgs, crane, ... }:

let
  craneLib = crane.mkLib pkgs;
  app = craneLib.buildPackage { src = craneLib.cleanCargoSource ./app; };
  
in {
  imports = [
    ./modules/rk3588-boot.nix
    (lib.mkAliasOptionModule [ "networking" "defaultHostName" ] [ "networking" "hostName" ])
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  # The 26.05 default kernel (6.18) predates the CM5 device tree.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Every dts/<name>.dts, built against the kernel's sources. U-Boot boots the one named by
  # hardware.rk3588.fdtfile, so all compute modules share this system.
  hardware.deviceTree.dtbSource = pkgs.runCommandCC "dtbs" { nativeBuildInputs = [ pkgs.dtc ]; } ''
    tar xf ${config.boot.kernelPackages.kernel.src} --strip-components=1 \
      --wildcards --no-wildcards-match-slash '*/include' '*/arch/arm64/boot/dts'
    mkdir $out
    for dts in ${./dts}/*.dts; do
      $CC -E -nostdinc -Iinclude -Iarch/arm64/boot/dts -undef -D__DTS__ -x assembler-with-cpp $dts |
        dtc -I dts -O dtb -@ -o $out/$(basename $dts .dts).dtb
    done
  '';

  networking.defaultHostName = "cm5";
  # cm5 default, subsequent devices on the same network will have -1, -2, etc. appended to the hostname.
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.addresses = true;
  };
  services.openssh.enable = true;
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # deploy-rs activates as root through sudo
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWN8FrD/kX6O+Ss4ksODDKwOOEsQQGfpkmsvzSPjnpD antho@Anthonys-MacBook-Pro.attlocal.net-thor-deploy"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "root" "deploy" ]; # accept deploy-rs's unsigned store paths

  systemd.services.app = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${app}/bin/app";
      DynamicUser = true;
      Restart = "always";
    };
  };

  system.stateVersion = "26.05";
}
