{
  description = "A Nix-flake-based Go 1.22 development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      systems,
      nixpkgs-unstable,
      ...
    }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      checks = forEachSystem (system: {
        pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            gofmt.enable = true;
            gotest.enable = true;
            golines.enable = true;
            govet.enable = false;

            nixfmt-rfc-style.enable = true;
          };
        };
      });

      devShells = forEachSystem (system: {
        default =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
            inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
          in
          pkgs.mkShell {
            GOROOT = "${pkgs.go}/share/go";

            shellHook = ''
              ${shellHook}

              export PATH="$PATH:$(${pkgs.go}/bin/go env GOPATH)/bin"
              export GOPACKAGESDRIVER="./tools/gopackagesdriver.sh"
            '';
            buildInputs = enabledPackages;

            hardeningDisable = [ "fortify" ];

            packages = [
              pkgs.go
              pkgs.gotools
              pkgs.gopls
              pkgs.go-swag
              pkgs.go-task
              pkgs-unstable.bazel_9
            ];
          };
      });
    };
}
