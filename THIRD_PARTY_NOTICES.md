# Third-Party Notices

## Flight-model research

Hyzer Flip's independently authored flight-model implementation was informed by:

Giljarhus, K. E. T., Gooding, M. T., & Njærheim, J. (2022). *Disc golf
trajectory modelling combining computational fluid dynamics and rigid body
dynamics*. *Sports Engineering*, 25, 26.
<https://doi.org/10.1007/s12283-022-00390-5>

The article is licensed under [Creative Commons Attribution 4.0
International](https://creativecommons.org/licenses/by/4.0/). Hyzer Flip
changes the coordinate implementation, integration method, authored
aerodynamic coefficients, and validation workflow. No code or aerodynamic
coefficient data from the GPL-3.0 Shotshaper repository is included in this
project.

## FrisPy flight-model reference

Hyzer Flip independently adapted the gyroscopic angular-momentum precession
relationship and aerodynamic spin-damping form after reviewing FrisPy at commit
`6fe3a7618248bbbf781b60a3abe17c17eb2c87be`.

Source: <https://github.com/TDisc/FrisPy/tree/6fe3a7618248bbbf781b60a3abe17c17eb2c87be>

No FrisPy source files, named-mold configurations, aerodynamic coefficient
data, or research documents are included in Hyzer Flip. The following MIT
notice is retained for the adapted implementation:

```text
MIT License

Copyright (c) 2019 Tom McClintock
Copyright (c) 2021 John Carrino

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
