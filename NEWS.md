# vglmer 1.0.3

* Adjust `vglmer` to not throw deprecation messages with Matrix 1.5. Thank you to Mikael Jagan for suggestions on how to adapt the code.

# vglmer 1.0.2

* IMPORTANT: Fixes bug where prediction with only one spline  (and no random effects) was wrong; the non-linear part of the spline was ignored.
* Smaller bug fixes around splines (e.g., for using a single knot) have been added as well as updated tests.

# vglmer 1.0.1

* Patch to address compiler issues on CRAN
* Add links to GitHub to description

# vglmer 1.0.0

* Initial submission to CRAN. Estimates linear, binomial, and negative binomial (experimental) models.
