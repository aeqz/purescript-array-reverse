{ name = "my-project"
, dependencies = [ "arrays", "control", "maybe", "partial", "prelude", "safely", "st", "tailrec" ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
