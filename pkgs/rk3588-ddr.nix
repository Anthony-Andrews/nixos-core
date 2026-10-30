# Rockchip's RK3588 DDR init with `settings` written in by their ddrbin_tool.
{
  lib,
  runCommand,
  python3,
  rkbin,
  settings,
}:

let
  params = lib.concatStrings (lib.mapAttrsToList (key: value: "${key}=${toString value}\n") settings);
in
runCommand "rk3588-ddr.bin" { nativeBuildInputs = [ python3 ]; } (
  ''
    install -m644 ${rkbin}/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v*.bin $out
  ''
  # A blank --ver_edit keeps the version string instead of stamping in the build time.
  + lib.optionalString (settings != { }) ''
    python3 ${rkbin}/tools/ddrbin_tool.py rk3588 ${builtins.toFile "ddrbin_param.txt" params} $out --ver_edit=' '
  ''
)
