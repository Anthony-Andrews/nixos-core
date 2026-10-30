# RK3588 boot chain: Rockchip's DDR init (optionally re-parameterised), mainline U-Boot
# and open TF-A, written into an image for maskrom flashing with rkdeveloptool.
{
  config,
  lib,
  pkgs,
  modulesPath,
  rkbin,
  ...
}:

let
  ddr = pkgs.callPackage ../pkgs/rk3588-ddr.nix {
    inherit rkbin;
    settings = config.hardware.rk3588.ddrSettings;
  };
  # Mainline U-Boot has no CM5 board; the generic RK3588 target boots eMMC/SD and gives
  # Linux the system's dtbs/<fdtfile> (extlinux FDTDIR).
  uboot = pkgs.buildUBoot {
    defconfig = "generic-rk3588_defconfig";
    extraConfig = ''
      CONFIG_DEFAULT_FDT_FILE="${config.hardware.rk3588.fdtfile}"
    '';
    extraMeta.platforms = [ "aarch64-linux" ];
    env = {
      BL31 = "${pkgs.armTrustedFirmwareRK3588}/bl31.elf";
      ROCKCHIP_TPL = "${ddr}";
    };
    filesToInstall = [ "u-boot-rockchip.bin" ];
  };
in
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  options.hardware.rk3588 = {
    ddrSettings = lib.mkOption {
      type = with lib.types; attrsOf (either int str);
      default = { };
      description = ''rkbin ddrbin_param.txt values written into the DDR init, e.g. "channel mask" = 3.'';
    };
    fdtfile = lib.mkOption {
      type = lib.types.str;
      description = "Device tree in the system's dtbs that U-Boot boots Linux with.";
    };
  };

  config = {
    # Maskrom loader for `rkdeveloptool db`: Rockchip's recipe (DDR init + usbplug) with our
    # DDR init swapped in. boot_merger is a static x86_64 binary, hence qemu.
    system.build.maskromLoader = pkgs.runCommand "rk3588-loader.bin" { } ''
      ln -s ${rkbin}/bin bin
      install -m644 ${ddr} ddr.bin
      sed -E 's#^(Path1|FlashData)=bin/rk35/rk3588_ddr_.*#\1=ddr.bin#' ${rkbin}/RKBOOT/RK3588MINIALL.ini > loader.ini
      ${pkgs.qemu-user}/bin/qemu-x86_64 ${rkbin}/tools/boot_merger loader.ini
      install -m644 rk3588_loader_*.bin $out
    '';

    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;

    sdImage = {
      compressImage = false; # rkdeveloptool writes raw images only
      firmwarePartitionOffset = 32; # MiB; U-Boot runs from sector 64 past 8 MiB
      populateFirmwareCommands = "";
      populateRootCommands = ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      '';
      postBuildCommands = "dd if=${uboot}/u-boot-rockchip.bin of=$img seek=64 conv=notrunc";
    };
  };
}
