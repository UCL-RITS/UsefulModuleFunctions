#
# Package of useful functions to use in modules, collated from existing module files.
#
# v1.0                                                                H.K. July 2014
#
# To use:
#    package require modulefunctions 1.0
# and then
#    modulefunctions::createSymlink $from $to
#

package provide modulefunctions 1.0
package require Tcl             8.4

namespace eval ::modulefunctions {
    namespace export createSymlink createDir copySource isMember getCluster isCluster isModuleLoad isTMPDIR randomLabel randomLabelN
}

# Create a symlink in user space
proc ::modulefunctions::createSymlink { newlink sourcefile } {

    if { ![file exists $newlink] } { # symlink doesn't exist at destination
        puts stderr ""
        puts stderr "$newlink doesn't exist - creating"  
        puts stderr ""
        if { [catch {file link $newlink $sourcefile} err] } {
            puts stderr "Cannot link from $newlink to $sourcefile:"
            puts stderr "    $err"
            puts stderr "Note: you must load this module at least once from a login node."
            return false
        }
        return true
    } else { # symlink exists already
        puts stderr "Using existing $newlink"
        return true
    }
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
proc ::modulefunctions::copySource { sourcefile copytarget } {

    if { ![file exists $copytarget] } { # copytarget doesn't exist at destination
        puts stderr ""
        puts stderr "$copytarget doesn't exist - creating"
        puts stderr ""
        if { [catch {file copy $sourcefile $copytarget} err] } {
            puts stderr "failed to copy $sourcefile to $copytarget:"
            puts stderr "    $err"
            puts stderr "Note: you must load this module at least once from a login node."
            return false
        }
        return true
    } else { # source exists at destination already
        puts stderr "Using existing $copytarget"
        return true
    }
}

# Check if user is in a group, print error if they aren't
# Uses numeric group ids as SGE's extra numeric groups cause group name errors.
proc ::modulefunctions::isMember { group } {
    # get the ids of the user's groups
    set p1 [open "| /usr/bin/id --groups"]
    set mygids [read $p1]
    if {[catch {close $p1} err]} {
        puts stderr "id command failed: $err"     
    }
    # get the id of the group we are checking
    set p2 [open "| getent group $group"]
    set appgroup [read $p2]
    if {[catch {close $p2} err]} {
        puts stderr "getent command failed: $err"
    }
    # getent output looks like 'group:*:nnnn:username,username'
    # third item is the gid.
    set appgid [exec awk -F: {{print $3}} << $appgroup]
    # compare ids
    if { [lsearch -exact $mygids $appgid] != -1 } {
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

# Return which cluster this is.
proc ::modulefunctions::getCluster { } {
#    set hostname [exec whereami]
    set fp [open "/opt/sge/default/common/cluster_name" r]
    set hostname [read $fp]
    close $fp
    if { [string match *legion* $hostname] } {
        set name "legion"
    } elseif { [string match *grace* $hostname] } {
        set name "grace"
    } elseif { [string match *thomas* $hostname] } {
        set name "thomas"
    } elseif { [string match *myriad* $hostname] } {
        set name "myriad"
    } elseif { [string match *michael* $hostname] } {
        set name "michael"
    } elseif { [string match *kathleen* $hostname] } {
        set name "kathleen"
    } elseif { [string match *aristotle* $hostname] } {
        set name "aristotle"
    } else {
        set name "unknown"
    }
    return $name
}

# Check if this is a specific cluster (not case-sensitive).
# Returns true (1) if identical, false (0) if not.
proc ::modulefunctions::isCluster { name } {
  set cluster [::modulefunctions::getCluster]
  return [string equal -nocase $cluster $name]
}

# Check if user is loading module - only want to use many of the above
# on module load.
proc ::modulefunctions::isModuleLoad { } {
    
    return [ module-info mode load ]
}

# Check if TMPDIR exists
proc ::modulefunctions::isTMPDIR { } {

    return [ info exists ::env(TMPDIR) ]
}

# Check if this is a job (whether $NHOSTS exists)
proc ::modulefunctions::isJob { } {
    return [ info exists ::env(NHOSTS) ]
}

# Gives a random hex label N(=8) characters long
#  Good for temporary directories and files
proc randomLabel {} {
    return [randomLabelN 8]
}

proc randomLabelN {num} {
    return [format %0${num}x [expr int((16**$num)*[::tcl::mathfunc::rand])]]
}


