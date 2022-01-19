# cocoapods-bin-cache

A patch for cocoapods-binary by which you can cache prebuild binaries in a local path specified,besides,there are some function to eliminate bundle/dsyms copy bugs of cocoapods-binary.

## Installation
    $ gem install cocoapods-binary
    $ gem install cocoapods-bin-cache

## Usage
    in Podfile:
    plugin 'cocoapods-binary-cache'
    fix_bundle_copy (optional, when you prebuild in static framework,you may encounter bundle copy problem,just fix it by call this method) 
    fix_dsyms_copy (optional,just like fix_bundle_copy,this is for dsyms_copy during dynamic framework prebuilding)
