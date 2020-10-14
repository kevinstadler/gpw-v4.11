## gpw-v4.11 population density tiles

Transparent TMS raster tiles of the [Gridded Population of the World](http://sedac.ciesin.columbia.edu/data/set/gpw-v4-population-density-rev11) 30 arc-second population density dataset for 2015, created using [gdal2tiles.py](http://www.gdal.org/gdal2tiles.html).

> Center for International Earth Science Information Network - CIESIN -
> Columbia University. 2017. Gridded Population of the World, Version 4
> (GPWv4): Population Density, Revision 10. Palisades, NY: NASA
> Socioeconomic Data and Applications Center (SEDAC).
> <https://doi.org/10.7927/H4DZ068D>. Accessed 8 May 2018.

The purpose of the tiles is to be used in my [borders](https://kevinstadler.github.io/borders/) web map project, so the original data is transformed in two ways:

### numerical transformation

[In an earlier dataset](/kevinstadler/gpw-tiles/), population density is truncated from its original floating-point maximum of 55189 inhabitants/km² down to the byte-resolution \[0,255\] range. While this leads to significant loss of information about population density in urban cores, the data still captures the visually more relevant progression from uninhabited over rural to urban (see histograms below as well as Figure 4 in [this article](http://www.newgeography.com/content/004349-from-jurisdictional-functional-analysis-urban-cores-suburbs)).

In the current tileset, population information is divided into red, green (16 pre-comma bits) and blue (8 post-comma bits) channels. In hindsight this is not a great idea because compression algorithms will alter the least significant bits of each channel equally, so even the slightest compression to the red channel is gonna throw off the population density by steps of 512. Interleaving the significant bits across all 3 channels (say with 3x5=15 pre- and 3x3=9 post-comma bits) would be the best option, but also requires somewhat more intensive reconstitution processing before rendering.
