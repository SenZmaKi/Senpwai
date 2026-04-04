{
  description = "A flake to install Senpwai";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      senpwai = pkgs.python312Packages.callPackage ./default.nix {};
      default = self.packages.${system}.senpwai;
    };
  };
}
