{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix/master";
  inputs.gitignore = {
    url = "github:hercules-ci/gitignore.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
  inputs.nixpkgsMaster.url = "github:NixOS/nixpkgs/master";

  outputs = { self, flake-utils, gitignore, haskellNix, nixpkgs, nixpkgsMaster }:
    flake-utils.lib.eachSystem ["x86_64-linux"] (system:
      let
        compiler-nix-name = "ghc9121";

        pkgsMaster = import nixpkgsMaster { inherit system; };

        overlays = [
          haskellNix.overlay

          # Set enableNativeBignum flag on compiler
          (final: prev: {
            haskell-nix = let
              shouldPatch = name: compiler: prev.lib.hasPrefix compiler-nix-name name;

              overrideCompiler = name: compiler: (compiler.override {
                enableNativeBignum = true;
              });
            in
              prev.lib.recursiveUpdate prev.haskell-nix {
                compiler = prev.lib.mapAttrs overrideCompiler (prev.lib.filterAttrs shouldPatch prev.haskell-nix.compiler);
              };
          })

          # Configure hixProject
          (final: prev: {
            hixProject = compiler-nix-name:
              final.haskell-nix.hix.project {
                src = gitignore.lib.gitignoreSource ./.;
                evalSystem = system;
                inherit compiler-nix-name;

                modules = [{
                  packages.aarch64-cpp-repro.components.exes.aarch64-cpp-repro.dontStrip = false;
                } (
                  pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin (import ./nix/macos-modules.nix { inherit pkgs; })
                )];
              };
          })
        ];

        pkgs = import nixpkgs { inherit system overlays; inherit (haskellNix) config; };

        flake = (pkgs.hixProject compiler-nix-name).flake {};
        flakeStatic = (pkgs.pkgsCross.musl64.hixProject compiler-nix-name).flake {};
        flakeAarch64Linux = (pkgs.pkgsCross.aarch64-multiplatform.hixProject compiler-nix-name).flake {};

      in
        {
          devShells = {
            default = pkgs.mkShell {
              NIX_PATH = "nixpkgs=${pkgsMaster.path}";
              buildInputs = [];
            };
          };

          packages = (rec {
            inherit (pkgs) cabal2nix stack;

            default = static;

            static = flakeStatic.packages."aarch64-cpp-repro:exe:aarch64-cpp-repro";
            dynamic = flake.packages."aarch64-cpp-repro:exe:aarch64-cpp-repro";
            aarch64Linux = flakeAarch64Linux.packages."aarch64-cpp-repro:exe:aarch64-cpp-repro";

            nixpkgsPath = pkgsMaster.writeShellScriptBin "nixpkgsPath.sh" "echo -n ${pkgsMaster.path}";
          });

          inherit flake;
        }
    );

  # nixConfig = {
  #   # This sets the flake to use the IOG nix cache.
  #   # Nix should ask for permission before using it,
  #   # but remove it here if you do not want it to.
  #   extra-substituters = ["https://cache.iog.io"];
  #   extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
  #   allow-import-from-derivation = "true";
  # };
}
