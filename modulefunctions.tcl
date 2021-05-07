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
    namespace export createSymlink createDir copySource isMember mustBeMember mustBeMemberToLoad getCluster isCluster isModuleLoad isTMPDIR randomLabel randomLabelN tmpdirVar
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
        return false
    }
}

# Check if user is in group, break if they aren't (this prevents modules loading)
proc ::modulefunctions::mustBeMember { group {failureNote ""} } {
    if { ! [ isMember $group ] } {
        puts stderr ""
        puts stderr " Access to the software this module refers to:"
        puts stderr [format "    %s" [module-info name]]
        puts stderr "  is granted by membership of the group:"
        puts stderr [format "    %s" $group]
        puts stderr ""
        puts stderr " You are not currently a member of this group."
        puts stderr ""
        puts stderr " Please email: "
        puts stderr ""
        puts stderr "    rc-support@ucl.ac.uk"
        puts stderr ""
        puts stderr " to request access to the software."
        if {[string length failureNote] != 0} {
            puts stderr ""
            puts stderr [format "    %s" $failureNote]
            puts stderr ""
        }
        puts stderr ""
        puts stderr "=================================="
        puts stderr ""
        break
    }
}

# Convenience
proc ::modulefunctions::mustBeMemberToLoad { group } {
    if { [isModuleLoad] } {
        mustBeMember $group
    }
}

# Return which cluster this is.
proc ::modulefunctions::getCluster { } {
    if { [file exists "/opt/sge/default/common/cluster_name"] } {
        set fp [open "/opt/sge/default/common/cluster_name" r]
        set hostname [read $fp]
        close $fp
    } else {
        set hostname [exec hostname -f]
    }
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
    } elseif { [string match *young* $hostname] } {
        set name "young"
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

# Check if this node has any disks.
# Returns true (1) if yes, false (0) if no.
proc ::modulefunctions::nodeHasDisks { } {
    if { [catch { exec lsblk -l -n -o NAME } msg] } {
        puts stderr "This module tried to work out whether this node has local storage, and failed."
        puts stderr "The error message it received is below:\n\n$::errorInfo"
        break
    }
    return [ expr { $msg != "" } ]
}

# Check if this node is a login node.
# Returns true (1) if yes, false (0) if no.
proc ::modulefunctions::nodeIsLoginNode { } {
    return [string match login* [info hostname]]
}

# Gets the amount of free space (in KB) available in the storage
#  containing the temporary storage
proc ::modulefunctions::getTmpdirFreeSpace { } {
    # if no tmpdir then assume /tmp
    if { [info exists ::env(TMPDIR)] } {
        set targetDir $::env(TMPDIR)
    } else {
        set targetDir /tmp
    }
    return [ ::modulefunctions::getDirFreeSpace $targetDir ]
}

# Gets the amount of free space (in KB) available in the storage
#  containing a directory.
proc ::modulefunctions::getDirFreeSpace {targetDir} {
    if { [catch { exec df --output=avail "$targetDir" } msg] } {
        puts stderr "This module tried to work out how much space was in \n storage containing the path below, and failed."
        puts stderr "Path: $targetDir"
        puts stderr "The error message it received is below:\n\n$::errorInfo"
        break
    }

    # delete the df header
    set result [string trim $msg " Avail\n"]
    return $result
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

# These three functions are for programs which have their own
#  variable to specify a temporary directory, to make it be
#  TMPDIR within jobs but XDG_RUNTIME_DIR on login nodes.
proc ::modulefunctions::tmpdirVar { varname } {
    modulefunctions::tmpdirVarWithSubdir $varname ""
}

proc ::modulefunctions::tmpdirVarWithRandomSubdir { varname subdirStub } {
    modulefunctions::tmpdirVarWithSubdir $varname /$subdirStub.[randomLabel]
}

proc ::modulefunctions::tmpdirVarWithSubdir { varname subdir } {
    if {[string length $subdir] != 0} {
        set slash /
    } else {
        set slash ""
    }
    if [modulefunctions::isTMPDIR] {
        setenv $varname $::env(TMPDIR)$slash$suffix
        # Acts like mkdir -p
        file mkdir $varname
    } else {
        setenv $varname $::env(XDG_RUNTIME_DIR)$slash$suffix
        # Acts like mkdir -p
        file mkdir $varname
    } 
}

# Gives a random hex label N(=8) characters long
#  Good for temporary directories and files
proc randomLabel {} {
    return [randomLabelN 8]
}

proc randomLabelN {num} {
    return [format %0${num}x [expr int((16**$num)*[::tcl::mathfunc::rand])]]
}

# Read /proc/cpuinfo and check if this is an arch we are interested in. 
# Example use: loading avx512 build instead of earlier one.
proc ::modulefunctions::getArch { } {
    if { [file exists "/proc/cpuinfo"] } {
        set fp [open "/proc/cpuinfo" r]
        # read just the flags line and put the whole match in $cpuflags
        regexp -line {^flags.*\s} [read $fp] cpuflags
        close $fp
    }
    # Right now we only have one flavour of avx512 node, so
    # check if any of our flags start with avx512. 
    # (avx512f avx512dq avx512cd avx512bw avx512vl avx512_vnni ...)
    # 'string first' finds the first occurrence of the substring and returns 
    # the index of where it starts, or -1 if not present.
    if { [string first " avx512" $cpuflags] != -1 } {
        set thisarch "avx512"
    } elseif { [string first " avx2 " $cpuflags] != -1 } {
        set thisarch "avx2"
    } elseif { [string first " sse2 " $cpuflags] != -1 } {
        set thisarch "sse2"
    } else {
        set thisarch "unknown"
    }
    return $thisarch
}

# Check if this has a specific arch (not case-sensitive).
# Returns true (1) if identical, false (0) if not.
proc ::modulefunctions::hasArch { arch } {
    set thisarch [::modulefunctions::getArch]
    return [string equal -nocase $thisarch $arch]
}

