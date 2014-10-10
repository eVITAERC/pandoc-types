Scholdoc-Types
==============

### Document structure for [Scholdoc][scholdoc]

**Current stable version:** 0.1.3

**Development build status** [![build status][scholarly-devel-travisimage]][travis_stat]  
**Stable build status** [![build status][scholarly-travisimage]][travis_stat]


This project contains definitions of the document structure used for
[Scholdoc][scholdoc], a fork of Pandoc that understands [ScholarlyMarkdown][scholmd]. This package is a fork of [Pandoc-Types][pandoc-types]
intended to support the development of [Scholdoc][scholdoc]. It includes some
non-trivial extensions to the Pandoc data types and builder functions that are
not easily implemented by depending on and extending the
[Pandoc-Types][pandoc-types] modules.

This package is currently up to date with [Pandoc-Types][pandoc-types] version
1.12.4

[scholmd]: http://scholarlymarkdown.com
[scholdoc]: https://github.com/timtylin/scholdoc
[pandoc-types]: https://github.com/jgm/pandoc-types
[travis_stat]: https://travis-ci.org/timtylin/scholdoc-types
[scholarly-devel-travisimage]: https://travis-ci.org/timtylin/scholdoc-types.svg?branch=scholarly-devel
[scholarly-travisimage]: https://travis-ci.org/timtylin/scholdoc-types.svg?branch=scholarly
