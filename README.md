# ParaViewer

[![Build Status](https://github.com/cenmir/ParaViewer.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/cenmir/ParaViewer.jl/actions/workflows/CI.yml?query=branch%3Amain)

ParaViewer is a package for visualizing vtu files using ParaView. Object properties can be set and ParaView is either launched and displays the object for further manipulation using the GUI or a png file is just generated without opening the GUI.

Example:

```julia
Display(Visualization(VTUObjects=[VTUObject("active.vtu"),
                                  VTUObject("Ω.vtu", faceColoring=[1.0, 0.8980, 0.4980])
]), headless=false);
```

ParaViewer uses the python API to configure the visualization.

## Installation

```julia
using Pkg
Pkg.add("https://github.com/cenmir/ParaViewer.jl")
```

### Dependencies

ParaViewer is configured using the config.toml file in the src folder. 

- You need to specify the path to paraview on your system to use the GUI
- You need to specify the path to pvpython to visualize headlessly
- You need to specify the path to your system python installation which is the same as the one used by ParaView.

Running `ParaViewer._GetParaViewPythonVersion` or just the `Display()` function normally, ParaViewer will display which python version is needed.

## Usage
`Display` takes a `Visualization` type as an input which in turn takes a list of `VTUObject` types as input.

### Display() 
`Display(Visualization, headless=false)`

`headless=false` By default ParaView will not launch the GUI, pvpython is called and a picture generated.

### Visualization()

`Visualization(VTUObjects=[vtuObj1, vtuObj2], filename="pic.png", resolution=[2000,2000])`

`filename="pic.png"` The default file name of the visualization screenshot
`resolution=[2000, 2000]` The default resolution of the visualization

### VTUObject()

```julia
VTUObject(filename; 
    representation="Surface With Edges", 
    faceOpacity=1.0, 
    coloring="Solid Color", 
    faceColoring=[0.8,0.8,0.8],
    edgeColoring=[0.1, 0.1, 0.1], 
    edgeOpacity=0.7)
```
`filename` The filename of the input file to ParaView

`representation` Can be "Surface With Edges" or "Surface"


## License

[MIT](https://choosealicense.com/licenses/mit/)