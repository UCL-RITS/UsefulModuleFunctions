#
# Package of useful functions to use in modules, collated from existing module files.
#
# v1.0                                                                H.K. July 2014
#

package provide modulefunctions 1.0
package require Tcl             8.4

namespace eval ::modulefunctions {
    namespace export createSymlink createDir copySource isMember isModuleLoad
}

# Create a symlink in user space
proc ::modulefunctions::createSymlink { from to } {

    if { [catch {file link $from $to} err] } {
        puts stderr "Cannot link from $from to $to:"
        puts stderr "    $err"
        return false
    }
    return true
}

# Create a directory in user space. mkdir creates any missing
# dirs in the specified path. Retuns with no error if dir exists.
# Retuns error if trying to overwrite a file with a dir.
# Note: does not move existing user directory. 
proc ::modulefunctions::createDir { path } {

    if { [catch {file mkdir $path} err] } {
        puts stderr ""
        puts stderr "failed to create $path"
        puts stderr "    $err"
        return false
    }
    puts stderr ""
    puts stderr "$path is configured"
    return true
}

# Copies source (file or dir) to user space. Reminds that module must be 
# loaded at least once from a login node if copy fails.
proc ::modulefunctions::copySource { from to } {

    if { ![file exists $to] } { # source doesn't exist at destination
        puts stderr ""
        puts stderr "$to doesn't exist - creating"
        puts stderr ""
        if { [catch {file copy $from $to} err] } {
            puts stderr "failed to copy $from to $to:"
            puts stderr "    $err"
            puts stderr "Note: you must load this module at least once from a login node."
            return false
        }
        return true
    } else { # source exists at destination already
        puts stderr "Using existing $to"
        return true
    }
}

# Check if user is in a group, print error if they aren't
proc ::modulefunctions::isMember { group } {

    set p1 [open "| /usr/bin/groups"]
    set myGroups [read $p1]
    if {[catch {close $p1} err]} {
        puts stderr "groups command failed: $err"
    }
    if { [lsearch -exact $myGroups $group] != -1 } {
        return true
    } else {
        puts stderr ""
        puts stderr "You are not currently a member of the reserved application group"
        puts stderr "for this module. Please email"
        puts stderr ""
        puts stderr "    rc-support@ucl.ac.uk"
        puts stderr ""
        puts stderr "requesting access to the software."
        puts stderr ""
        puts stderr "=================================="
        puts stderr ""
        return false
    }
}

# Check if user is loading module - only want to use many of the above
# on module load.
proc ::modulefunctions::isModuleLoad { } {
    
    return [ module-info mode load ]
}
