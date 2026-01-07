{
  description = "Lean Vim - A minimalist Neovim configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # CLI tools required by the config
        runtimeDeps = with pkgs; [
          fzf
          ripgrep
          bat
          fd
          git
        ];

        # The wrapped neovim package
        lean-vim = pkgs.callPackage ./nix/default.nix {
          inherit runtimeDeps;
        };

      in
      {
        packages = {
          default = lean-vim;
          lean-vim = lean-vim;
        };

        apps.default = {
          type = "app";
          program = "${lean-vim}/bin/nvim";
        };

        # DevShell for users who are cloning to ~/.config/nvim
        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [ pkgs.neovim ];
          shellHook = ''
            echo "The Lean Vim environment"
            echo "Tools: fzf, rg, bat, fd, git, nvim"
          '';
        };
      }
    );
}
