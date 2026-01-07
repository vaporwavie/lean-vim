{ lib
, stdenv
, neovim-unwrapped
, makeWrapper
, runtimeDeps
}:

let
  configDir = builtins.path {
    path = ./..;
    name = "lean-vim-config";
    filter = path: type:
      let
        baseName = baseNameOf path;
      in
      baseName != "flake.nix" &&
      baseName != "flake.lock" &&
      baseName != "nix" &&
      baseName != ".git" &&
      baseName != "result";
  };

in
stdenv.mkDerivation {
  pname = "lean-vim";
  version = "0.1.0";

  src = configDir;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ neovim-unwrapped ] ++ runtimeDeps;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Create config directory structure
    mkdir -p $out/share/nvim/config
    cp -r $src/* $out/share/nvim/config/

    # Create the wrapper script
    mkdir -p $out/bin
    makeWrapper ${neovim-unwrapped}/bin/nvim $out/bin/nvim \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} \
      --set XDG_CONFIG_HOME "$out/share/nvim" \
      --set NVIM_APPNAME "config"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Lean Vim - A minimalist Neovim configuration";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
