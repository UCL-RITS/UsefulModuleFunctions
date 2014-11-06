UsefulModuleFunctions
=====================

Useful functions for writing modules in TCL.

To use:

    lappend auto_path <full/path/to/UsefulModuleFunctions/dir>
    package require modulefunctions 1.0

and then

    modulefunctions::createSymlink $from $to
    
Functions contained and usage
-----------------------------

#### `createSymlink` ####

Create a symlink, printing out an error if it fails to be created.
Example usage:

    modulefunctions::createSymlink $from $to

#### `createDir` ####
    
Create a directory in user space, including parents - does the equivalent of mkdir -p. Returns with no error if the directory exists, returns with an error if you try to overwrite a directory with a file. Note: does not move any existing user directory of the same name. Outputs "$path is configured" to the user.
Example usage:

    modulefunctions::createDir $path
    
#### `copySource` ####
    
Copies the source file or directory to user space. Informs the user of what is being created. Informs the user if the copy fails and outputs a reminder that the module must be loaded at least once from a login node. If the file or directory exists, tells the user it is using the existing one.

    modulefunctions::copySource $from $to
    
#### `isMember` ####
    
Check if the user is a member of the specified group. Gives an error if the groups command fails. If the user isn't in the group, says "You are not currently a member of the reserved application group for this module. Please email rc-support@ucl.ac.uk requesting access to the software."

    modulefunctions::isMember $group

#### `isModuleLoad` ####
    
Check if the user is loading the module. Otherwise the function will be carried out on module unload as well.

    if [modulefunctions::isModuleLoad] {
        # do stuff
    }
