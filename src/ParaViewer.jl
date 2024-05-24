module ParaViewer
# Used to visualize VTU files using ParaView

import TOML
export VTUObject, Visualization, Display

const _verbose = true  
const _paraViewPythonEnvironmentDir = "paraViewPythonEnv" 
_moduleDir = ""
_pvpythonPath = ""
_paraviewPath = ""
_pythonPath = ""
_configPath = ""

mutable struct VTUObject
    filename::String
    representation::String
    faceOpacity::Float64
    coloring::String
    faceColoring::Array{Float64}
    edgeColoring::Array{Float64}
    edgeOpacity::Float64

    function VTUObject(filename; representation::String="Surface With Edges", 
                                 faceOpacity::Float64=1.0, 
                                 coloring="Solid Color", 
                                 faceColoring::Array{Float64}=[0.8,0.8,0.8],
                                 edgeColoring::Array{Float64}=[0.1, 0.1, 0.1], 
                                 edgeOpacity::Float64=0.7)
        
        if !(representation in ["Surface With Edges", "Surface"])
            error("representation must be 'Surface With Edges' or 'Surface'")
        end
        if length(faceColoring) != 3
            error("faceColoring must be of length 3")
        end
        if length(edgeColoring) != 3
            error("edgeColoring must be of length 3")
        end
        
        return new(filename, representation, faceOpacity, coloring, faceColoring, edgeColoring, edgeOpacity)
    end
end

mutable struct Visualization
    filename::String
    resolution::Array{Int64}
    VTUObjects::Array{ParaViewer.VTUObject}

    function Visualization(; filename="pic.png", resolution=[2000, 2000], VTUObjects=[])
        return new(filename, resolution, VTUObjects)
    end
end

function Display(visu::ParaViewer.Visualization; headless::Bool=true)
    _verbose && println("Exporting visualization to $(visu.filename)")
    _verbose && println("headless: $headless")

    global _moduleDir = @__DIR__
    global _configPath = joinpath(_moduleDir, "config.toml")
    
    data = TOML.parsefile(_configPath);
    #vscodePath = data["General"]["vscodePath"]
    global _pvpythonPath = data["General"]["pvpythonPath"]
    global _paraviewPath = data["General"]["paraviewPath"]
    global _pythonPath = data["General"]["pythonPath"]   
    if !isfile(_pvpythonPath)
        error("File '$_pvpythonPath' does not exist!\nMake sure you are pointing to the correct file in config.toml file at $_configPath")
    end

    paraViewPythonEnvironmentPath = _checkPythonEnvironment()
    println("Using python environment at '$paraViewPythonEnvironmentPath'")
    ENV["PV_VENV"] = paraViewPythonEnvironmentPath

    data["PrevExport"] = Dict("imageFileName" => visu.filename, 
                          "imageResolution"   => visu.resolution,
                          "vtuFiles"          => [vtu.filename for vtu in visu.VTUObjects],
                          "representation"    => [vtu.representation for vtu in visu.VTUObjects],
                          "faceOpacity"       => [vtu.faceOpacity for vtu in visu.VTUObjects],
                          "edgeColoring"      => [vtu.edgeColoring for vtu in visu.VTUObjects])

    data["PrevExport"]["edgeOpacity"]     = [vtu.edgeOpacity for vtu in visu.VTUObjects]
    data["PrevExport"]["faceColoring"]    = [vtu.faceColoring for vtu in visu.VTUObjects]
    open(_configPath,"w") do io
        TOML.print(io, data)
    end

    vizPyPath = _CheckVizPy(paraViewPythonEnvironmentPath)

    _verbose && println("Running paraview python script: '$vizPyPath'")
    
    if headless
        println("Running paraview python headless script...")
        run(`"$_pvpythonPath" --force-offscreen-rendering "$vizPyPath"`)
    else
        println("Launching paraview and running script...")
        run(`"$_paraviewPath" "$vizPyPath"`)
    end
    
end

function _GetParaViewPythonVersion()
    # pyVersion.py checks the python version of ParaView
    pyVersionPath = joinpath(_moduleDir,"pyVersion.py")
    open(pyVersionPath,"w") do IO
        print(IO, """
    from paraview.simple import * # type: ignore
    
    from platform import python_version
    print(python_version())
        """)
    end
    
    isfile(_pvpythonPath)
    if !isfile(_pvpythonPath)
        error("The path to ParaView python '$_pvpythonPath' does not exist! \nMake sure you are pointing to the correct file in config.toml file at $_configPath.")
    end
    
    # Run the pyVersion script and return the ParaView python version
    io = IOBuffer();
    cmd = pipeline(`"$_pvpythonPath" $pyVersionPath`; stdout=io)
    processID = run(cmd, wait=true)
    paraviewPythonVersionStr = String(take!(io))
    
    println("")
    printstyled("Paraview python version: $paraviewPythonVersionStr\n"; color = :blue)

    return paraviewPythonVersionStr
end

function _GetSystemPythonVersion()
    # Check the system python 
    isfile(_pythonPath)
    if !isfile(_pythonPath)
        error("The path to python '$_pythonPath' does not exist! \nMake sure you are pointing to the same version of python as paraview uses in the config.toml file at $_configPath.")
    end
    
    # Check the system python version
    io = IOBuffer();
    cmd = pipeline(`"$_pythonPath" -V`; stdout=io)
    processID = run(cmd, wait=true)
    systemPythonVersionStr = String(take!(io))

    println("")
    println("Paraview python version: $systemPythonVersionStr")

    return systemPythonVersionStr
end

function _checkPythonEnvironment()
    paraViewPythonEnvironmentPath = joinpath(_moduleDir, _paraViewPythonEnvironmentDir)
    # If the environment exitst return true
    if isdir(paraViewPythonEnvironmentPath)
        return paraViewPythonEnvironmentPath
    end
    
    
    paraviewPythonVersionStr = _GetParaViewPythonVersion()
    
    systemPythonVersionStr = _GetSystemPythonVersion()
    
    
    # Check if the system python version matches the ParaView Python version
    re = r"(\d)\.(\d{1,2})\.(\d{1,2})"
    paraviewPythonVersion = match(re, paraviewPythonVersionStr)
    systemPythonVersion = match(re, systemPythonVersionStr)
    
    isSameVersion = paraviewPythonVersion[1] == systemPythonVersion[1] && 
                    paraviewPythonVersion[2] == systemPythonVersion[2] &&
                    paraviewPythonVersion[3] == systemPythonVersion[3]
    
    
    if !isSameVersion
        error("The system python version $(systemPythonVersion.match) does not match the ParaView python version $(paraviewPythonVersion.match)! \
        \nPlease update the path to the system python version in the config.toml file at $_configPath.")
    end
    
    
    # Use the system python the create python environment in the module directory
    paraViewPythonEnvironmentPath = joinpath(_moduleDir,_paraViewPythonEnvironmentDir)
    _verbose && println("Paraview environment not found, creating environment at '$paraViewPythonEnvironmentPath' using python '$_pythonPath'")
    processID = run(`"$_pythonPath" -m venv $paraViewPythonEnvironmentPath`, wait=true)
    if !success(processID)
        error("Error creating virtual environment '$paraViewPythonEnvironmentPath'")
    end
    _verbose && println("Virtual environment successfully created.")
    

    # Activate the python environment
    #_verbose && println("Activating environment...")
    #cmd = `"$_pythonPath" joinpath($paraViewPythonEnvironmentPath, "Scripts", "Activate.ps1")`
    #_verbose && println(cmd)
    #processID = run(cmd, wait=true)
    #processID.exitcode == 0 ? println("Success.") : println("Failure!")    

    # Use the system python to generate the requred modules
    _verbose && println("Installing toml module using pip...")
    pythonPath = joinpath(paraViewPythonEnvironmentPath, "Scripts", "python.exe")
    processID = run(`"$pythonPath" -m pip install toml`, wait=true)
    processID.exitcode == 0 ? println("Success.") : println("Failure!")
    
    
    return paraViewPythonEnvironmentPath
end

function _CheckVizPy(paraViewPythonEnvironmentPath)

    vizPyPath = joinpath(_moduleDir,"viz.py")
    if isfile(vizPyPath)
        return vizPyPath
    end
    
    _verbose && println("viz.py not found, creating script at '$vizPyPath'")
    open(vizPyPath,"w") do IO
        print(IO, _vizPy(paraViewPythonEnvironmentPath))
    end

    _verbose && println("viz.py successfully created.")

    return vizPyPath
end

function _vizPy(paraViewPythonEnvironmentPath)
    return """
    # trace generated using paraview version 5.12.0-RC1
    #import paraview
    #paraview.compatibility.major = 5
    #paraview.compatibility.minor = 12

    #### import the simple module from the paraview
    from paraview.simple import * # type: ignore

    import os

    print("------------ viz.py script ------------")

    srcDir = os.path.dirname(os.path.realpath(__file__))
    print(f"srcDir: {srcDir}" )
    scriptDir = os.path.realpath(os.path.dirname(__name__))
    print(f"scriptDir: {scriptDir}" )
    virtEnvPath = os.path.join(srcDir, "$_paraViewPythonEnvironmentDir")
    print(f"virtEnvPath: {virtEnvPath}" )
    os.environ['PV_VENV'] = virtEnvPath

    from paraview.web import venv # type: ignore

    import toml # type: ignore

    configFilePath = os.path.join(srcDir, "config.toml")
    print("configFilePath: ", configFilePath)
    config = toml.load(configFilePath)
    vtuFiles =           config["PrevExport"]["vtuFiles"]
    faceColors =         config["PrevExport"]["faceColoring"]
    representationType = config["PrevExport"]["representation"]
    edgeColor =          config["PrevExport"]["edgeColoring"]
    edgeOpacity =        config["PrevExport"]["edgeOpacity"]
    imageResolution =    config["PrevExport"]["imageResolution"]
    imageFileName =      config["PrevExport"]["imageFileName"]
    faceOpacity =        config["PrevExport"]["faceOpacity"]

    renderView = GetActiveViewOrCreate('RenderView') # type: ignore
    for i, vtuFile in enumerate(vtuFiles):
        print(vtuFile)
        currentVtu = XMLUnstructuredGridReader(registrationName=vtuFile, FileName=[os.path.join(scriptDir,vtuFile)]) # type: ignore
        SetActiveSource(currentVtu) # type: ignore
        
        currentVtuDisplay = Show(currentVtu, renderView, 'UnstructuredGridRepresentation') # type: ignore
        currentVtuDisplay.SetRepresentationType(representationType[i])
        currentVtuDisplay.AmbientColor = faceColors[i]
        currentVtuDisplay.DiffuseColor = faceColors[i]
        currentVtuDisplay.Opacity = faceOpacity[i]
        try:
            currentVtuDisplay.EdgeColor = edgeColor[i]
            currentVtuDisplay.EdgeOpacity = edgeOpacity[i]
        except Exception as e:
            print("No Edge property")
            print(e)


    renderView.ResetActiveCameraToNegativeZ()
    renderView.ResetCamera(False, 1.0)


    SaveScreenshot(os.path.join(scriptDir,imageFileName), renderView, 16, ImageResolution=imageResolution, # type: ignore
        OverrideColorPalette='WhiteBackground',
        TransparentBackground=0,
        SaveInBackground=1, 
        # PNG options
        CompressionLevel='5')


    """
end


end
