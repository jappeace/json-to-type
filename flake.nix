# I used chatgpt to generate this template and then just
# modified to how I normally use these things.
{
  description = "My Haskell project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-compat }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      hpkgs = pkgs.haskellPackages.override {
        overrides = hnew: hold: {
          json-to-type = hnew.callCabal2nix "json-to-type" ./. { };
        };
      };
    in
    {
      defaultPackage.x86_64-linux =  hpkgs.json-to-type;
      inherit pkgs;
      devShell.x86_64-linux = hpkgs.shellFor {
        packages = ps : [ ps."json-to-type" ];
        withHoogle = true;

        buildInputs = [
          hpkgs.haskell-language-server
          pkgs.ghcid
          pkgs.cabal-install
        ];
      };
    };
}
