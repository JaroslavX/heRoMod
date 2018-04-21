# heRomod - A Package for Health Economic Modeling

The heRomod package allows users to develop and run cost-effectiveness models in R and is the calculation engine used in the heRo web-based modeling platform.  A fork of the HEEMOD package.

You can install:

  * the latest released version from github with:

```r
devtools::install_github("heRomod")
```

## Features

Main features:

  * Support for Markov cohort and partitioned-survival models.
  * Comprehensive tools for defining and operation of survival distribtions.
  * Probabilistic uncertainty analysis (PSA).
    * Cost-effectiveness acceptability curves (CEAC).
    * Expected value of perfect information (EVPI).
    * Expected value of partially perfect information (EVPPI).
  * Deterministic sensitivity analysis (DSA).
  * Value-based pricing analysis (VBP).

Most of the analyses presented in [Decision Modelling for Health Economic Evaluation](http://ukcatalogue.oup.com/product/9780198526629.do) can be performed with `heemod`. See the *Reproducing Exact Results from DMHEE* vignette for an exact reproduction of the analyses from the book.

## Learning heemod

To get started read the *An Introduction to `heemod`* vignette. Specific analysis examples (mostly inspired from [Decision Modelling for Health Economic Evaluation](http://ukcatalogue.oup.com/product/9780198526629.do)) can be found in the package vignettes.

## Devs
  * [Jordan Amdahl](https://github.com/jrdnmdhl)

## Contributors
  * [Kevin Zarca](http://www.urc-eco.fr/Kevin-ZARCA,402) and [Antoine Filipović-Pierucci](https://pierucci.org) (authors of HEEMOD).
  * [Matthew Wiener](https://github.com/MattWiener)
  * [Zdenek Kabat](https://github.com/zkabat)
  * [Vojtech Filipec](https://github.com/vojtech-filipec)
  * [Yonatan Carranza Alarcon](https://github.com/salmuz)
  * [Vince Daniels](https://github.com/daniels4321)
  * [Fernando Alarid](https://github.com/feralaes)
  
