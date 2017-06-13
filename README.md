# TorXakis

TorXakis is a tool for Model Based Testing.

It is licensed under the [BSD3 license](LICENSE).

## For Users
User documentation at [our wiki](https://github.com/TorXakis/TorXakis/wiki).

## For Developers
TorXakis is written in [Haskell](www.haskell.org).

TorXakis uses [stack](www.haskellstack.org) to build.

TorXakis needs a [SMT](https://en.wikipedia.org/wiki/Satisfiability_modulo_theories) Solver, such as 
[cvc4](http://cvc4.cs.stanford.edu/web/) and [Z3](https://github.com/Z3Prover/z3).
The SMT Solver needs to support [SMTLIB](http://smtlib.cs.uiowa.edu/) version 2.5,
[Algebraic Data Types](https://en.wikipedia.org/wiki/Algebraic_data_type), and [Strings](http://cvc4.cs.stanford.edu/wiki/Strings).
The SMT Solvers are assumed to be located on the [PATH](https://en.wikipedia.org/wiki/PATH_(variable)).



