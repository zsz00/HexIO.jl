using Documenter, HexIO

makedocs(;
    modules=[HexIO],
    format=Documenter.HTML(edit_link="master"),
    pages=[
        "Introduction" => "index.md",
        "Example" => "example.md",
        "API" => "apis.md",
    ],
    sitename="HexIO.jl",
    authors="zsz00",
)

deploydocs(;
    repo="github.com/zsz00/HexIO.jl.git",
    devbranch = "master",
    push_preview = true
)
