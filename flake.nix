{
  description = "My OCaml project";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.opam-nix.url = "github:tweag/opam-nix";
  inputs.mynvim.url = "github:marnyg/nixos";
  # inputs.mynvim.url = "path:/home/mar/git/nixos";
  inputs.nixvim.url = "github:nix-community/nixvim";
  inputs.neorg-overlay.url = "github:nvim-neorg/nixpkgs-neorg-overlay";
  inputs.neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";


  outputs = { nixvim, mynvim, nixpkgs, ... }@inputs:
    let
      pkgs = import nixpkgs
        {
          system = "x86_64-linux";
          overlays = [
            inputs.neovim-nightly-overlay.overlays.default
            inputs.neorg-overlay.overlays.default
          ];
        };

      mynixvim =
        nixvim.legacyPackages.x86_64-linux.makeNixvimWithModule
          {
            inherit pkgs; module = {
            imports = [ mynvim.nixvimModules.nixVim { langs.terraform.enable = true; } ];
          };
          };

      myShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixd
          opentofu

        ];
        packages = [
          mynixvim
          (pkgs.azure-cli.withExtensions [ pkgs.azure-cli.extensions.azure-devops ])
        ];
      };
    in
    {
      # packages.x86_64-linux.default = myPro;
      # apps.x86_64-linux.default = { type = "app"; program = "${myPro}/bin/day02"; };
      # checks.x86_64-linux.tests = pkgs.stdenv.mkDerivation {
      #   name = "dune-test";
      #   buildInputs = [ myPro ];
      #   src = ./.;
      #   checkPhase = "dune test && touch $out/ok ";
      #   installPhase = "echo No installation needed for test && mkdir -p $out && touch $out/testOK";
      # };

      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
      devShells.x86_64-linux.marnyg = myShell;
    };
}

