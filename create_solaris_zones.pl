#!/usr/bin/perl

################################################################################
# $Id: create_pp_ctp.pl 1513 2011-03-22 16:45:42Z diarmuid $
#
#  DESCRIPTION:  This program is used to generate a zone in which a user
#                configurable version of the Prepaid system is installed.
#
#        USAGE: create_daily.pl [-z <zone-name>]
#                               [-c <config file>]
#                               [-a <ip address> -i <interface>]
#                               [-f (full root zone)]
#                               [-S (Don't check free disk Space)]
#
#     EXAMPLES:
#                create_pp_ctp.pl
#                        ( Zonename = ctp-1-<timestamp>, uses default config )
#
#                create_pp_ctp.pl -z local -c my.config
#                        ( Installs on local machine, no zone created, uses my.config config file )
#
#                create_pp_ctp.pl -z ctp-1-test
#                        ( Zonename = ctp-1-test, uses default config file )
#
#                create_pp_ctp.pl -z ctp-1-test
#                        ( Zonename = ctp-1-test, uses default config file )
#
#                create_pp_ctp.pl -c my.config -z ctp-1-test
#                        ( Zonename = ctp-1-test, uses config file "my.config" )
#
#                create_pp_ctp.pl -f -z ctp-1-test
#                        ( Zonename = ctp-1-test, Creates a full root zone )
#
#                create_pp_ctp.pl -i hme0 -a 192.168.50.144 -z ctp-1-ip
#                        ( Zonename = ctp-1-ip, ip address assigned to hme0 )
#
#         DOCS: See http://samlab1.tecnomen.ie/ppzone/ppzone.html
#
#     PERLTIDY: -b -l=200 -mbl=2
#
################################################################################

use strict;
use warnings;

use File::Basename;
use File::Copy;
use Getopt::Std;
use Config::IniFiles;

$|++;

my $start_time = localtime();
print( "** Started: " . $start_time . "\n" );

# Config options.
my $install_path         = "/opt/TINUppzone/";
my $zone_share_basedir   = "/export/share";
my $global_share_basedir = $install_path . "zone_shares";
my $zonehome             = "/export/zones/";
my $basezone             = "base-zone";
my $fullzone             = "full-zone";
my $pkgadd_admin_file    = "install.admin";
my $csi_log              = "/tmp/SybaseInstall.log";
my $create_db_log        = "/logs/apps/CreateDatabases.pl-0.log";
my $cap2sim_dir          = "cap2callgen";
my $pkg_dir              = "packages";
my $config_dir           = $install_path . "config";
my $exomi_licence        = $install_path . "3rdParty/exomi_licence.txt";
my $TINPemg_path         = "/global/sdp/ThirdParty/TINPemg";

my %args;

# Allow an url to be entered as an argument.
getopts( "lSfc:z:a:i:j:", \%args );

if ( defined( $args{'l'} ) ) {
    $zone_share_basedir   = $install_path . "zone_shares";
}

# Set the zone name.
my $zonename = "";
my $InstallType = "zone";

if ( defined( $args{'l'} ) ) {
    $InstallType = "local";
    $zonename = `hostname`;
    chomp $zonename;
    print "NOTE: '-l' flag used. Installing CTP locally. Not creating new zone.\n"
}


if ( !defined( $args{'l'} ) ) {
    if ( !defined( $args{'z'} ) ) {
        die("!! No zone/machine defined, use the -z argument for zone install or -l for local install!\n");
    } else {
        # Set the zone name.
        $zonename = set_zonename( $args{'z'} );
    }
}

print "Using zone name '" . $zonename . "'.\n";

# Set the platform type (default ctp).
my $platform_type = "ctp";

# Decide which config file to use.
my $config_file = "/opt/TINUppzone/config/";
if ( !defined( $args{'c'} ) ) {
    die("!! No Configuration file defined, use the -c argument!\n");
}
else {
    $config_file .= $args{'c'};
}

my @ip = ();

# Check are we going to define an IP address.
if ( !defined( $args{'l'} ) ) {     # if we're not installing locally, need
                                    # an ip address and interface for the zone.
    if ( ( defined( $args{'i'} ) ) xor( defined( $args{'a'} ) ) ) {
        die("Both -i and -a options are required together!\n");
    }
    elsif ( ( defined( $args{'i'} ) ) && ( defined( $args{'a'} ) ) ) {
		if  ( defined( $args{'i'} ) ) {
			my @interfacelist = `ifconfig -a | grep IPv4 | cut -f 1 -d ' '` ;
			# print @interfacelist ;
			if ( grep ( /$args{'i'}/ , @interfacelist ) ) {
				print "'" .  $args{'i'} . "' looks like a valid interface on this machine.\n";
			} else {
				die ( "Could not find '" . $args{'i'} . "' in list of interfaces on this machine.\nPlease check the supplied -i parameter, and ensure it contains a valid interface name.\n" ) ;
			}
		}
        if ( $args{'a'} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ )

          # There's an even more accurate way of doing this, but hey...
        {
        	$ip[0] = $args{'a'};
        	$ip[1] = $args{'i'};
			print "Will attempt to assign IP address '" . $ip[0] . "' on '" . $ip[1] . "'.\n" ;
        }
        else {
        	die("IP address \"$args{'a'}\" doesn't look right!\n");
        }
    }
}

# Check whether we're going to create a sparse or full root zone (default sparse).
my $clone_zone_type = $basezone;
if ( !defined( $args{'l'} ) ) {     # not installing locally, allow fullzone.
    if ( defined( $args{'f'} ) ) {
        $clone_zone_type = $fullzone;
        print("** Going to create a FULL-ROOT zone!\n");
    }
}

# Check for space on the disk.
if ( !defined( $args{'S'} ) ) {
    check_diskspace( $clone_zone_type, $zonehome );
}
else {
    print("** Not doing a pre-check for disk space.\n");
}
open( our $CMDS, ">", $zonename . ".cmds" ) or warn("!! Couldn't open zlogin .cmds file\n");

# Check does this zonename already exist.
if ( !defined( $args{'l'} ) ) {     # installing zone, check if exists already.
    print "Checking if zone is previosly installed ($zonename)...\n";
    check_previously_installed($zonename);
}

# Fetch the packages.
my $cfg = get_packages( $config_file, $pkg_dir );
 
if ( my $zone_home = $cfg->val( "options", "zone_home" ) ) 
{
  $zonehome = $zone_home;
}

# Decide whether we're installing a pre 5.10 platform and 12.5 sybase.
my $old_platform    = 0;
my $sybase_dir      = "sybase15";
my $sybase_main_dir = "ase15";
if ( $cfg->val( "options", "old_platform" ) ) {
    $old_platform    = 1;
    $sybase_dir      = "sybase125";
    $sybase_main_dir = "ase125";
    print("** Pre 5.10 platform\n");
}
else {
    print("** 5.10 platform or later\n");
}

# Define some combination paths.
my %zone_data = ();
$zone_data{'zonename'}           = $zonename;
$zone_data{'plat_type'}          = $platform_type;
$zone_data{'old_plat'}           = $old_platform;
$zone_data{'gz_zone_home'}       = $zonehome . $zonename;
$zone_data{'gz_sybase_dir'}      = $global_share_basedir . "/" . $sybase_dir;
$zone_data{'lz_sybase_dir'}      = $zone_share_basedir . "/" . $sybase_dir;
$zone_data{'lz_sybase_main_dir'} = $zone_data{'lz_sybase_dir'} . "/" . $sybase_main_dir;
$zone_data{'gz_cap2sim_dir'}     = $global_share_basedir . "/" . $cap2sim_dir;
$zone_data{'lz_cap2sim_dir'}     = $zone_share_basedir . "/" . $cap2sim_dir;
$zone_data{'gz_share_dir'}       = $global_share_basedir . "/" . $zonename;
$zone_data{'lz_share_dir'}       = $zone_share_basedir . "/" . $zonename;
# Directory is different for a local install, as directory permissions may
# be a problem.
if ( $InstallType eq 'zone' ) {
    $zone_data{'gz_path_to_lz_root'} = $zone_data{'gz_zone_home'} . "/root/";
} else {
    $zone_data{'gz_path_to_lz_root'} = "/";
}
$zone_data{'gz_share_log_dir'}   = $zone_data{'gz_share_dir'} . "/logs";
$zone_data{'lz_share_log_dir'}   = $zone_share_basedir . "/" . $zonename . "/logs";

# Set the version number used in the TIPSppvoice directory structure.
my $dir_version = '4.61';
if ( my $version = $cfg->val( "options", 'dir_version' ) ) {
    $dir_version = $version;
}

my $cgw_version = "2.15";
if ( my $version = $cfg->val( "options", 'cgw_version' ) ) {
    $cgw_version = $version;
}
#
# Set JTAF_HOST in the /etc/hosts file.
#

# 1. Default to the zone IP address.
my $jtaf_host = $ip[0];

# 2. Use the user specified IP from config.
if ( my $ip = $cfg->val( "options", 'jtaf_host' ) ) {
    $jtaf_host = $ip;
}

# 3. Overwrite user specified IP if running JTAF regression.
if ( defined( $args{'j'} && $args{'j'} eq 'run') ) {
    $jtaf_host = $ip[0];
}


# Get going!
create_share_directory( $zone_data{'gz_share_dir'} );

# Copy over the wget log if any packages were copied over http.
if ( -e "$pkg_dir/wget.log" ) {
    if ( system( "mv " . $pkg_dir . "/wget.log " . $zone_data{'gz_share_log_dir'} ) ) {
        warn("!! Couldn't move the wget log file!\n");
    }
}

# Move the build packages to the share directory.
print( "** " . $pkg_dir . " " . $zone_data{'gz_share_dir'} . "\n" );
system( "mv " . $pkg_dir . "/* " . $zone_data{'gz_share_dir'} ) == 0 or die("Couldn't move installation packages!\n");

# Copy over pkgadd admin script to the zone's shared directory.
print( $config_dir . "/" . $pkgadd_admin_file, $zone_data{'gz_share_dir'} );
copy( $config_dir . "/" . $pkgadd_admin_file, $zone_data{'gz_share_dir'} ) or die("Couldn't copy admin file! [$!]\n");

# Create the zone!
if ( !defined( $args{'l'} ) ) {     # installing zone, create the zone.
    create_daily_zone( \%zone_data, $clone_zone_type, \@ip );
}

# Modify etc_hosts.
modify_ctp_etc_hosts( $zone_data{'zonename'}, $zone_data{'gz_path_to_lz_root'} );

# Install all packages as set out in the configuration file.
install_packages( \%zone_data, $cfg, $TINPemg_path, $exomi_licence, $install_path );

# After installing all packages, check whether we want to configure site ini.
# Settings.
if ( $cfg->val( "options", "run_siteconfig" ) ) {
    run_siteconfig( \%zone_data, $cfg );
}

# Install jsmee if required.
if ( $cfg->val( "options", "install_jsmee" ) ) {
    install_jsmee();
}

if ( $cfg->val( "options", "install_sybase" ) ) {

    # Install sybase.
    my $res = install_sybase( \%zone_data );
    copy( $zone_data{'gz_path_to_lz_root'} . $csi_log, $zone_data{'gz_share_log_dir'} ) or warn("!! Couldn't copy csi log file! [$!]\n");
    if ($res) {
        die("Problem with install_sybase!\n");
    }

    # Weird profiles, directory permissions difference so chmod /opt/sybase.
    my $syb_dir = "";
    if ( $platform_type eq "ctp" ) {
        $syb_dir = "/opt/sybase";
    }
    else {
        $syb_dir = "/global/sdp/sybase";
    }
    my $cmd    = 'chmod 755 ' . $syb_dir . ' ' . $syb_dir . '/devices ' . $syb_dir . '/interfaces';
    my $user   = "root";
    my $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn( "!! Couldn't chmod " . $syb_dir . "\n" );
    }

    # Initialise sisql.
    initialise_sisql( $zone_data{'zonename'} );

    # Install scdr_db.
    if ( $cfg->val( "options", "create_scdr_db" ) ) {

        # Run the create database script for the scdr db's.
        # Find location of scdr data.
        my $cmd    = '. /.profile; printf %s $TINP_DB';
        my $user   = "root";
        my $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 1 );

        my $db_data_path = $output;
        chomp($db_data_path);
        if ( $db_data_path eq "" ) {
            die("Couldn't figure out TINP_DB!\n");
        }
        $res = install_db( $zone_data{'zonename'}, "SCDR_DB", $db_data_path, "all" );
        $cmd    = 'cp ' . $create_db_log . ' /export/share/' . $zone_data{'zonename'} . '/logs/scdr_' . basename($create_db_log);
        $user   = 'root';
        $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );
        if ( $output != 0 ) {
            print( "!! Couldn't copy " . $create_db_log . " to shared log directory!\n" );
        }
    }

    # Add the VR_DB for PTAF testing.
    if ( $cfg->val( "options", "create_vr_db" ) ) {
        $res = install_db( $zone_data{'zonename'}, "VR_DB", "/opt/TINSppvoice/$dir_version/db/vr", "all" );
        my $cmd    = 'cp ' . $create_db_log . ' /export/share/' . $zone_data{'zonename'} . '/logs/vr_' . basename($create_db_log);
        my $user   = 'root';
        my $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );
        if ( $output != 0 ) {
            print( "!! Couldn't copy " . $create_db_log . " to shared log directory!\n" );
        }

        if ($res) {
            die("Problem with CreateDatabase script!\n");
        }

        # Load the services default data.
        if ( $cfg->val( "options", "load_services_db_data" ) ) {
            $res = load_db( $zone_data{'zonename'}, "VR_DB", "/opt/TINSppvoice/$dir_version/db/vr" );
        }

        # Load the cc objects and data for the vr_db.
        if ( $cfg->val( "options", "install_customer_care" ) ) {
            $res = install_db( $zone_data{'zonename'}, "VR_DB", "/opt/TINCdb/$dir_version/db/vr", "objs" );
            if ($res) {
                die("!! Problem when loading CC vr objects\n");
            }

            # Load the cc pp_db default data
            $res = load_db( $zone_data{'zonename'}, "VR_DB", "/opt/TINCdb/$dir_version/db/si" );
        }
    }

    # Install si_db.
    if ( $cfg->val( "options", "create_si_db" ) ) {
        $res = install_db( $zone_data{'zonename'}, "SI_DB", "/opt/TINSppvoice/$dir_version/db/si", "all" );
        my $cmd    = 'cp ' . $create_db_log . ' /export/share/' . $zone_data{'zonename'} . '/logs/si_' . basename($create_db_log);
        my $user   = 'root';
        my $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );
        if ( $output != 0 ) {
            print( "!! Couldn't copy " . $create_db_log . " to shared log directory!\n" );
        }

        if ($res) {
            die("Problem with CreateDatabase script!\n");
        }

        # Load the services default data.
        if ( $cfg->val( "options", "load_services_db_data" ) ) {
            $res = load_db( $zone_data{'zonename'}, "SI_DB", "/opt/TINSppvoice/$dir_version/db/si" );
        }

        # Load the cc objects and data for the si_db.
        if ( $cfg->val( "options", "install_customer_care" ) ) {
            $res = install_db( $zone_data{'zonename'}, "SI_DB", "/opt/TINCdb/$dir_version/db/si", "objs" );
            if ($res) {
                die("!! Problem when loading CC si objects\n");
            }

            # Load the cc pp_db default data.
            $res = load_db( $zone_data{'zonename'}, "SI_DB", "/opt/TINCdb/$dir_version/db/si" );
        }
    }

    # Install pp_db.
    if ( $cfg->val( "options", "create_pp_db" ) ) {
        $res = install_db( $zone_data{'zonename'}, "PP_DB", "/opt/TINSppvoice/$dir_version/db/pp", "all" );
        my $cmd    = 'cp ' . $create_db_log . ' /export/share/' . $zone_data{'zonename'} . '/logs/pp_' . basename($create_db_log);
        my $user   = 'root';
        my $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );
        if ( $output != 0 ) {
            print( "!! Couldn't copy " . $create_db_log . " to shared log directory!\n" );
        }

        if ($res) {
            die("!! Problem with Installing Services PP DB\n");
        }

        # Load the services default data.
        if ( $cfg->val( "options", "load_services_db_data" ) ) {
            $res = load_db( $zone_data{'zonename'}, "PP_DB", "/opt/TINSppvoice/$dir_version/db/pp" );
        }

        # Run PP_DB upgrade script if required.
        if ( my $upgrade_sql = $cfg->val( "options", "upgrade_pp_db" ) ) {
            $res = upgrade_pp_db( $zone_data{'zonename'}, "/opt/TINSppvoice/$dir_version/db/pp/upgrades", $upgrade_sql );
        }

        # Load the cc objects and data for the pp_db.
        if ( $cfg->val( "options", "install_customer_care" ) ) {
            $res = install_db( $zone_data{'zonename'}, "PP_DB", "/opt/TINCdb/$dir_version/db/pp", "objs" );
            if ($res) {
                die("Problem when loading CC pp objects\n");
            }

            my $cmd    = '';
            my $user   = "tecnomen";
            my $output = '';

            # Workaround for RQ60122, invalid SP_DB initial data.
            $cmd    = "perl -i -ne '\\''print if ! /APIWhiteList/'\\'' /opt/TINCdb/$dir_version/db/si/initialdata/loadData.sql";
            $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );

            # Workaround for RQ60124, invalid PP_DB initial data.
            $cmd    = "perl -i -ne '\\''print if ! /OrderOfUsageInfo/'\\'' /opt/TINCdb/$dir_version/db/pp/initialdata/loadData.sql";
            $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );

            # Load the cc pp_db default data.
            $res = load_db( $zone_data{'zonename'}, "PP_DB", "/opt/TINCdb/$dir_version/db/pp" );
            $res = load_db( $zone_data{'zonename'}, "VR_DB", "/opt/TINCdb/$dir_version/db/vr" );
            $res = load_db( $zone_data{'zonename'}, "SI_DB", "/opt/TINCdb/$dir_version/db/si" );
        }

    }

    # Install cc_db.
    if ( $cfg->val( "options", "install_customer_care" ) ) {
        $res = install_db( $zone_data{'zonename'}, "CC_DB", "/opt/TINCdb/$dir_version/db/cc", "all" );
        if ($res) {
            die("Problem when Installing CC_DB\n");
        }

        # Load the cc_db default data.
        $res = load_db( $zone_data{'zonename'}, "CC_DB", "/opt/TINCdb/$dir_version/db/cc" );

        # Install voucher management on cc_db.
        $res = install_db( $zone_data{'zonename'}, "CC_DB", "/opt/TINCdb/$dir_version/db/vm", "objs" );
        if ($res) {
            die("Problem when Installing VM on CC_DB\n");
        }

        # Load the cc_db default data.
        $res = load_db( $zone_data{'zonename'}, "CC_DB", "/opt/TINCdb/$dir_version/db/vm" );

        # Start apache.
        start_apache( $zone_data{'zonename'} );
    }
}

# Install the CGW.
if ( $cfg->val( "options", "install_cgw" ) ) {
    run_cgw_postinstall($cgw_version);
}

# We install sybase64, add symlinks for 32 bit builds.
create_sybase_32_symlinks( $zone_data{'zonename'} );

# Install the cap2 call generator.
if ( $cfg->val( "options", "install_cap2_callgen" ) ) {
    run_cap2callgen( $zone_data{'zonename'} );
}

# Comment out tecnomen crontab.
if ( $cfg->val( "options", "comment_out_tecnomen_cron" ) ) {
    comment_tecnomen_cron( $zone_data{'gz_path_to_lz_root'} );
}

if ( $cfg->val( "options", "install_cap2_callgen" ) ) {
    print("** Waiting for mpr to come up:");
    my $waiting = 1;
    while ($waiting) {
        my $cmd    = 'pgrep mpr > /dev/null 2>&1';
        my $user   = 'root';
        my $output = zlogin( $zone_data{'zonename'}, $user, $cmd, 0 );

        # pgrep RETURNS POSITIVE IF A PROCESS IS NOT FOUND
        if ( !$output ) {
            print("ok\n");
            $waiting = 0;
            print("** Pausing to let pp system catch up with itself:");
            for ( my $i = 0 ; $i < 15 ; $i++ ) {
                print(".");
                sleep(1);
            }
            print("\n");
        }
        else {
            $waiting++;
            print(".");
            sleep(2);
        }

        if ( $waiting > 30 ) {
            print("No sign. Moving on.\n");
            last;
        }
    }
    make_cap2_call( $zone_data{'zonename'}, $zone_data{'gz_path_to_lz_root'} );
}

# Run any scripts defined in the [postinstall] section of the config file.
my @postinstalls = $cfg->GroupMembers( 'postinstall' );
for my $section ( @postinstalls ) {
    print("** Pre 5.10 platform\n");
}
for my $section ( @postinstalls ) {
    my $script = $cfg->val( $section, 'script' );
    my $user   = $cfg->val( $section, 'user' );
    my $path   = $cfg->val( $section, 'path' );
    my $args   = $cfg->val( $section, 'args' );

    next unless defined $script;
    run_postinstall_script( $ip[0], $zone_data{'zonename'}, $script, $user, $path, $args );
	sleep(10);
}



# Run the dataloader.
if ( $cfg->val( "options", "load_services_dataloader" ) ) {
    run_dataloader( $zone_data{'zonename'} );
}

# Need to update overseer.ini with the actual hostname.
my $cmd    = "cd \$TINP_CONFIG; sed 's/CTP/$zonename/' overseer.ini> newoverseer.ini;cp newoverseer.ini overseer.ini";
my $user   = "tecnomen";
my $output = zlogin( $zonename, $user, $cmd, 0 );
if ( $output != 0 )
{
	warn("!! Problem modifying overseer.ini!\n");
	next;
}

# For cc servers, seer must be restarted otherwise servers don't come up
# correctly. For sdp, seer never starts on initial install so start it
# now.
restart_seer( $zone_data{'zonename'} );

# Install and optionally run the JTAF test framework.
if ( defined( $args{'j'} ) ) {
    install_jtaf( $ip[0], $args{'j'} );
}

print( "** Started:  " . $start_time . "\n" );
print( "** Finished: " . localtime() . "\n" );
print("\nTo login to the new zone:\n    zlogin -l tecnomen $zonename\n\n");

close($CMDS) or warn("Couldn't close file for .cmds file handle\n");


################################################################################
#     FUNCTION: configure_network
#
#    ARGUMENTS: STRING        Zonename
#               STRING        path to root of zone
#               STRING        IP address of machine
#
#      RETURNS: NONE
#
#      PURPOSE: This function configures the /etc/resolv.conf,
#                /etc/nsswitch.conf and /etc/defaultrouter (if an ip-address was
#                supplied.
################################################################################
sub configure_network {
    my $zonename = shift;
    my $zoneroot = shift;
    my $ip       = shift;

    if ( defined($ip) ) {

        # Choose a (default) default route.
        my $default_route = $ip;
        $default_route =~ s/\.\d{1,3}$/.1/;

        my $cmd = 'echo ' . $default_route . ' > ' . $zoneroot . '/root/etc/defaultrouter';
        system($cmd) == 0 or warn("!! Couldn't create defaultrouter!");
    }

    # Create the resolv.conf file.
    my $resolv = <<THERE;
domain tecnomen.ie
nameserver 194.42.56.250
nameserver 194.42.62.39
search tecnomen.ie tecnomen.com tecnomen.fi tecnomen.net
THERE

    open( my $RESOLV, ">", $zoneroot . "/root/etc/resolv.conf" ) or warn("!! Couldn't create resolv.conf!\n");
    print( $RESOLV $resolv );
    close($RESOLV) or warn("Couldn't close resolv.conf file!\n");

    # Copy nsswitch.dns over nsswitch.files. This ensures dns is always available.
    my $cmd = "cp $zoneroot/root/etc/nsswitch.dns $zoneroot/root/etc/nsswitch.files";
    system($cmd) == 0 or warn("!! Couldn't copy in nsswitch.conf!\n");

    return;
}

################################################################################
#     FUNCTION: install_jsmee
#
#    ARGUMENTS: NONE
#
#      RETURNS: NONE
#
#      PURPOSE: Install JSMEE for Short Message Gateway.
################################################################################
sub install_jsmee {
    print( "*" x 80 );
    print("\n");
    print("** Installing JSMEE:\n");

    my $cmd    = 'cd /opt; tar xvf /net/genesis/export/install/JSMEE.tar';
    my $user   = "root";
    my $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't untar JSMEE.tar to /opt!\n");
        return;
    }
}

################################################################################
#     FUNCTION: run_siteconfig
#
#    ARGUMENTS: HASHREF        Contains zone information and directory layouts.
#               OBJECT        Config File data
#
#      RETURNS: NONE
#
#      PURPOSE: This function runs the TINUsiteconf configuration script, to
#               make modifications to pp ini files, as specified in a user
#               specified site configuration file.
################################################################################
sub run_siteconfig {
    my $zd  = shift;
    my $cfg = shift;

    # Pull in POM specific config from genesis.
    if ( $cfg->val( "options", "config_from_genesis" ) ) {

        print( "*" x 80 );
        print("\n");
        print("** Getting template updates from Genesis.");

        my $cmd    = "cp /net/genesis/export/install/TINPtmplt/$dir_version/* /mountp/tconfig";
        my $user   = "tecnomen";
        my $output = zlogin( $zd->{'zonename'}, $user, $cmd, 1 );

        print( "*" x 80 );
        print("\n");
        print("** Re-expanding all inifiles in \$TINP_CONFIG \n");
        $cmd    = 'cd $TINP_CONFIG; /mountp/tconfig/expand.sh CTP 1';
        $user   = "tecnomen";
        $output = zlogin( $zd->{'zonename'}, $user, $cmd, 1 );
    }

    print( "*" x 80 );
    print("\n");
    print("** Configuring prepaid ini files:\n");
    my $globalzone_config = $cfg->val( "siteconfig", "config" );
    my $config_filename = basename($globalzone_config);
    if ( !copy( $globalzone_config, $zd->{'gz_path_to_lz_root'} . "/export/home/tecnomen" ) ) {
        print("!! Couldn't copy $globalzone_config into the zone for ini site configuration!\n");
    }
    else {

        # Run the site config from within the zone.
        my $cmd    = 'cd /export/home/tecnomen; /opt/TINUsiteconf/bin/siteconfig.pl -c /export/home/tecnomen/' . $config_filename;
        my $user   = "tecnomen";
        my $output = zlogin( $zd->{'zonename'}, $user, $cmd, 1 );
        chomp($output);
        print( "**\n" . $output . "\n**\n" );
        print( "*" x 80 );
        print("\n");

        install_default_ini( $zd->{'zonename'}, 'pp.ini' );
        install_default_ini( $zd->{'zonename'}, 'cap2scf.ini' );
        install_default_ini( $zd->{'zonename'}, 'scf.ini' );
    }
}

################################################################################
#     FUNCTION: install_packages
#
#    ARGUMENTS: HASHREF        Contains zone information and directory layouts.
#               OBJECT        Config File data
#
#      RETURNS: NONE
#
#      PURPOSE: This function handles the package installation of all packages
#               and patches listed in the configuration file.
################################################################################
sub install_packages {
    my $zd            = shift;
    my $cfg           = shift;
    my $TINPemg_path  = shift;
    my $exomi_licence = shift;
    my $install_path  = shift;

    # Install the packages.
    my @package_data = $cfg->GroupMembers("package");
    foreach my $package (@package_data) {
        my ( $patch, $package_name ) = $package =~ /package(\s+patch|)\s+(\w+)/;
        my ( $pkg_file, $build_dir, $tmp ) = fileparse( $cfg->val( $package, 'location' ) );

        # Package file has already been uncompressed.
        my ($pkg) = $pkg_file =~ /(.+)\.(Z|gz|bz2)/;

        # If we can't find a compression extension then the package was delivered
        # uncompressed.
        if ( !defined($pkg) ) {
            $pkg = $pkg_file;
        }
        my $ptch = "";

        # The response file name.
        if ( $patch =~ /patch/ ) {
            $ptch = "_patch";
        }
        my $resp_file = $package_name . $ptch . ".resp";
        print( "** RESPONSE FILE: \"" . $resp_file . "\"\n" );
        my $resp_data = $cfg->val( $package, 'response' );

        # Some packages have an empty request script.
        my $no_request = $cfg->val( $package, 'norequest' );
        if ( !defined($no_request) ) {
            $no_request = 0;
        }

        # Install the package.
        install_zone_pkg( $zd, $platform_type, $pkg, $package_name, $resp_file, $resp_data, $no_request );

        # Modify the database.dat.tmpl and saprofile.imf, before they're expanded.
        # By tinpbase installation.
        if ( $package_name eq "TINPtmplt" ) {

            # Are there any patches.
            my $num_patches = $cfg->val( $package, "num_patch", 0 );
            print( "** Number of Patches: " . $num_patches . "\n" );
            if ($num_patches) {

                # Is this a patch file.
                if ( $patch =~ /patch/ ) {

                    # Is this the last patch file.
                    if ( $cfg->val( "package " . $package_name, "num_patch" ) == $num_patches ) {

                        # Last patch file, modify the templates.
                        if ( !$old_platform ) {
                            modify_db_tmpl( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'}, $cfg );
                            modify_SAprofile( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'}, $cfg );
                        }
                    }
                }
                else {

                    # If its not a patch, its the original package,
                    # but which will be patched, so we won't modify
                    # the template files yet.

                    # Do nothing!
                }

                # Workaround for the fact that some versions of 4.70 TINPtmpl don't
                # set the correct permissions on /logs/apps.
                my $cmd    = 'chown tecnomen:super /logs/apps';
                my $user   = "root";
                my $output = zlogin( $zonename, $user, $cmd, 0 );
                if ( $output != 0 ) {
                    warn("!! Couldn't $cmd\n");
                }

            }

            # If there's no patches, we can modify the templates now...
            else {
                if ( !$old_platform ) {
                    modify_db_tmpl( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'}, $cfg );
                    modify_SAprofile( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'}, $cfg );
                }
            }
        }
        elsif ( $package_name eq "TINSppvoice" ) {

            my $num_patches = $cfg->val( $package, "num_patch", 0 );
            print( "** Number of Patches: " . $num_patches . "\n" );

            # Is this a patch file.
            if ($num_patches) {
                if ( $patch =~ /patch/ ) {

                    # Is this the last patch file.
                    if ( $cfg->val( "package " . $package_name, "num_patch" ) == $num_patches ) {

                        # Last patch file.

                        # Perform the remote copy of files.
                        if ( $cfg->val( "options", "perform_remote_copy" ) ) {
                            perform_remote_copy( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'} );
                        }

                        # I think this should be done automatically like cc stuff
                        # but wasn't setup correctly in the platform software.
                    }
                }
            }
            else {

                # Perform the remote copy of files.
                if ( $cfg->val( "options", "perform_remote_copy" ) ) {
                    perform_remote_copy( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'} );
                }

                # I think this should be done automatically like cc stuff
                # but wasn't setup correctly in the platform software.
            }
        }
        elsif ( $package_name eq "TINPemg" ) {
            tinpemg_post_process( $zd->{'zonename'}, $exomi_licence, $zd->{'gz_path_to_lz_root'}, $TINPemg_path, $install_path );
        }
    }

    return;
}

################################################################################
#     FUNCTION: make_cap2_call
#
#    ARGUMENTS: STRING        Zonename
#               STRING         Global zone path to root of zone.
#
#      RETURNS: NONE
#
#      PURPOSE: THIS FUNCTION MAKES A DEFAULT CAP2 CALL AND CHECKS FOR A CDR.
################################################################################
sub make_cap2_call {
    my $zonename              = shift;
    my $global_zone_root_path = shift;

    my $cdr = '0,061932220,.+,2,-\d+,35361702332';

    # Create directory (bug in package).
    my $cmd    = './cap2sim/client/cap2cagen';
    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 1 );

    if ( $output !~ /OK:     IDP sent/ ) {
        print("** IDP sent successfully.\n");
    }
    else {
        print("!! IDP failed:\n$output\n");
        return;
    }

    print("** Waiting for CDR to arrive:");
    for ( my $i = 0 ; $i < 30 ; $i++ ) {
        print(".");
        if ( -s $global_zone_root_path . '/CDRs/pp/active_pp_1.cdr' ) {
            $i = 30;
            print("(cdr file found)");
        }
        sleep(1);
    }
    print("\n");

    $cmd    = 'tail -1 /CDRs/pp/active_pp_1.cdr';
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 1 );
    chomp($output);

    if ( $output =~ /$cdr/ ) {
        print("** CDR Received!\n");
        print("** Prepaid system is running correctly. (MO call).\n");
    }
    else {
        print("!! CDR not received. Please check Prepaid system manually!\n");
    }

    return;
}

################################################################################
#     FUNCTION: tinpemg_post_process
#
#    ARGUMENTS: STRING Path to root directory of zone, from global zone.
#
#      RETURNS: NONE
#
#      PURPOSE: THIS FUNCTION COMMENTS OUT TECNOMEN'S CRONTAB FILE.
################################################################################
sub comment_tecnomen_cron {
    my $global_zone_root_path = shift;

    my $tecnomen_cron = $global_zone_root_path . "/var/spool/cron/crontabs/tecnomen";

    open( my ($OUT), ">", "/tmp/tec.cron" ) or do {
        warn("!! Couldn't open temporary file for tecnomen's cron!\n");
        return;
    };
    open( my $IN, "<", $tecnomen_cron ) or do {
        warn("!! Couldn't open Tecnomen's crontab in zone!\n");
        return;
    };
    while (<$IN>) {
        my $line = $_;
        if ( $line !~ /^\s*#/ ) {
            $line = "#" . $line;
        }
        print( $OUT $line );
    }
    close($IN)  or warn("Can't close original tecnomen cron file: $tecnomen_cron\n");
    close($OUT) or warn("Can't close output file /tmp/tec.cron\n");

    my $cmd = "cp /tmp/tec.cron " . $tecnomen_cron;
    system($cmd) == 0
      or warn("!! Couldn't copy commented version of tecnomen's cron!\n");

    return;
}

################################################################################
#     FUNCTION: tinpemg_post_process
#
#    ARGUMENTS: STRING  Zonename
#                STRING Path to Exomi licence in global zone.
#                STRING Path to root directory of zone, from global zone.
#                STRING Path to where TINPemg is installed.
#                STRING Path to where TINUppzone is installed in global zone.
#
#      RETURNS: NONE
#
#      PURPOSE: THIS FUNCTION CARRIES OUT POST PROCESSING, AFTER THE TINPemg
#                PACKAGE HAS BEEN INSTALLED.
################################################################################
sub tinpemg_post_process {
    my $zonename              = shift;
    my $exomi_licence         = shift;
    my $global_zone_root_path = shift;
    my $TINPemg_path          = shift;
    my $install_path          = shift;

    # Create directory (bug in package).
    my $cmd    = 'mkdir -p $V7BASE/cl';
    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn(q{!! Couldn't mkdir $V7BASE/cl! Please complete this manually!\n});
    }

    # Copy licence file.
    if ( -e $exomi_licence ) {
        copy( $exomi_licence, $global_zone_root_path . $TINPemg_path . "/license.txt" ) or warn("!! Couldn't copy exomi licence file! [$!]\n");
        $cmd    = 'chown tecnomen:super ' . $TINPemg_path . '/license.txt';
        $user   = "root";
        $output = zlogin( $zonename, $user, $cmd, 0 );
        if ( $output != 0 ) {
            warn("!! Couldn't change owner of exomi licence!\n");
        }
    }
    else {
        print( "*" x 80 );
        print("\n**\n");
        print("** !! No licence file for exomi found !!\n");
        print("**\n");
        print("** If you have a valid licence file, it should be stored in the global zone as:\n");
        print("**\n");
        print("** $install_path/3rdParty/exomi_licence.txt\n");
        print("**\n");
        print( "*" x 80 );
        print("\n");
    }

    # Edit $v7base/config/http_mo for localhost.
    $cmd =
        q{sed 's/\(http_mo_url = "\).*\("\;\)/\1http:\/\/localhost:2323\/\2/' }
      . $global_zone_root_path
      . $TINPemg_path
      . "/config/svc/http_mo > "
      . $global_zone_root_path
      . $TINPemg_path
      . "/config/svc/http_mo.1";
    system($cmd) == 0 or warn("!! Couldn't sed the http_mo svc file for exomi!\n");
    $cmd    = "cp " . $TINPemg_path . "/config/svc/http_mo.1 " . $TINPemg_path . "/config/svc/http_mo";
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't overwrite the http_mo svc file for exomi!\n");
    }

    print( "*" x 80 );
    print("\n");
    print("** Starting emg processes:\n");
    print("**\n");
    $cmd    = 'emgstart';
    $user   = 'tecnomen';
    $output = zlogin( $zonename, $user, $cmd, 1 );
    print($output);
    print( "*" x 80 );
    print("\n");

    return;
}

################################################################################
#     FUNCTION: create_sybase_32_symlinks
#
#    ARGUMENTS: STRING Zonename
#
#      RETURNS: NONE
#
#      PURPOSE: SYBASE 64 BIT FILES ARE INSTALLED. SPORTS AND SOCIAL BUILDS ARE
#               DONE AGAINST 32 BIT SYBASE. SO CREATE SIMLINKS FROM SYBASE64
#               LIBS TO THE NAMES OF THE 32 BIT ONES...
################################################################################
sub create_sybase_32_symlinks {
    my $zonename      = shift;
    my $internal_path = "/opt/sybase/OCS-15_0/lib/";

    my $find_cmd = 'find ' . $internal_path . ' -name "*64.a"';
    my $user     = "root";
    my $output   = zlogin( $zonename, $user, $find_cmd, 1 );

    my @sybase_libs = split( /\n/, $output );

    foreach my $files (@sybase_libs) {
        chomp $files;
        if ( $files =~ /(.+)64.a/ ) {
            my $lnk_cmd = "ln -s " . $files . " " . $1 . ".a";
            my $output = zlogin( $zonename, $user, $lnk_cmd, 0 );
            if ( $output != 0 ) {
                warn("!! Couldn't softlink $files!\n");
            }
        }
    }

    return;
}

################################################################################
#     FUNCTION: check_diskspace
#
#    ARGUMENTS: STRING  Zone type.
#               STRING  Zone path.
#
#      RETURNS: NONE
#
#      PURPOSE: Check is there enough diskspace to create a complete zone.
################################################################################
sub check_diskspace {
    my $type      = shift;
    my $disk_path = shift;

    my $cmd    = "df -b " . $disk_path;
    my $output = `$cmd`;
    my ($freespace) = $output =~ /(\d+)$/;

    if ( $type eq "base-zone" ) {
        if ( $freespace < 3000000 ) {
            die(
"!! There is less than 3Gb left on the $disk_path partition.\n!! This probably isn't enough for a complete ctp install on a sparse root zone!\n!! If you would like to install anyway rerun this command with the the ignore disk space option -S\n"
            );
        }
    }
    elsif ( $type eq "full-zone" ) {
        if ( $freespace < 6000000 ) {
            die(
"!! There is less than 6Gb left on the $disk_path partition.\n!! This probably isn't enough for a complete ctp install on a full root zone!\n!! If you would like to install anyway rerun this command with the the ignore disk space option -S\n"
            );
        }
    }

    return;
}

################################################################################
#     FUNCTION: restart_seer
#
#    ARGUMENTS: STRING  Zone name.
#
#      RETURNS: NONE
#
#      PURPOSE: Starts Apache 1.3 for Customer Care
################################################################################
sub restart_seer {
    my $zonename = shift;

    my $cmd    = 'seerctl -m7';
    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Wasn't able to kill seer! (This may just mean that it wasn't running)\n");
    }
    else {

        # If we did kill seer, give it a chance to die properly.
        sleep(10);
    }

    $cmd    = 'seer -z';
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Wasn't able to restart seer!\n");
    }

    return;
}

################################################################################
#     FUNCTION: zlogin
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  User
#               STRING  Commandline to run
#               INT     runtype, 0 = system, 1 = ``
#               INT     Should the commandline be echoed to stdout
#
#      RETURNS: INT OR STRING (Caller must know which to expect)
#
#      PURPOSE: Starts Apache 1.3 for Customer Care
################################################################################
sub zlogin {
    my $zonename = shift;
    my $user     = shift;
    my $cmd      = shift;
    my $run_type = shift;
    my $printout = shift;
    my $zone_cmd = "";
    my $usr_str = "";
    my $result;


    if ( $InstallType eq 'local' ) {
        # Installing locally. Use 'su' to execute the command as the relevant user.
        $zone_cmd = "su - " . $user . " -c '" . $cmd . "'";
    } else {
        if ( $user eq "root" ) {
            $usr_str = "";
        }
        else {
           $usr_str = "-l " . $user;
        }
        $zone_cmd = "/usr/sbin/zlogin " . $usr_str . " " . $zonename . " '" . $cmd . "'";
    }

    print "zonecmd is " . $zone_cmd . ".\n";
    $printout && print( "** " . $zone_cmd . "\n" );
    print( $CMDS "<$user> " . $zone_cmd . "\n" );

    # system() captures the return status and backticks captures the output.
    if ( $run_type == 0 ) {
        $result = system($zone_cmd);
    }
    elsif ( $run_type == 1 ) {
        $result = `$zone_cmd`;
    }
    else {
        print("** Zlogin Error!($cmd)\n");
    }

    return ($result);
}


################################################################################
#     FUNCTION: start_apache
#
#    ARGUMENTS: STRING  Zone name.
#
#      RETURNS: NONE
#
#      PURPOSE: Starts Apache 1.3 for Customer Care
################################################################################
sub start_apache {
    my $zonename = shift;

    my $cmd    = 'cp /etc/apache/httpd.conf-example /etc/apache/httpd.conf';
    my $user   = "root";
    my $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't copy httpd.conf!\n");
        return;
    }

    $cmd    = '/usr/apache/bin/apachectl start';
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't start apache 1.3!\n");
    }

    return;
}

################################################################################
#     FUNCTION: run_cap2callgen
#
#    ARGUMENTS: STRING  Zone name.
#
#      RETURNS: NONE
#
#      PURPOSE: Installs and starts the cap2 call generator.
################################################################################
sub run_cap2callgen {
    my $zonename = shift;

    # TODO Fix this path for local install
    my $cmd    = 'cp /export/share/cap2callgen/cap2gen.tar /export/home/tecnomen';
    my $user   = "root";
    my $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't copy the cap2cagen tar file to ~tecnomen!\n");
        return;
    }

    $cmd    = 'tar -xvf cap2gen.tar';
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't untar cap2callgen.tar!\n");
        return;
    }

    $cmd    = 'cd cap2sim/server;./cap2tssf -rl -sl -el -d';
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't start cap2sim server!\n");
        return;
    }

    print("** CAP2 Server installed and started.\n");
    return;
}

################################################################################
#     FUNCTION: perform_remote_copy
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  Path to root directory of zone, from global zone.
#
#      RETURNS: NONE
#
#      PURPOSE: Runs the copy_remote_files.pl script for services data.
################################################################################
sub perform_remote_copy {
    my $zonename              = shift;
    my $global_zone_root_path = shift;

    # First we have to copy the services file into the right
    # place, (its a feature...).
    my $cmd        = 'echo ${NID_CONFIG}';
    my $user       = "tecnomen";
    my $output     = zlogin( $zonename, $user, $cmd, 1 );
    my $nid_config = $output;
    chomp($nid_config);
    copy( $global_zone_root_path . $nid_config . "/serv_copy_remote_files.ini", $global_zone_root_path . "/global/sdp/tconfig/etc/copy_remote_files" )
      or warn("!! Couldn't copy services ini file for copy_remote_files [$!]\n");

    # Have to set the path with the path to (3rd party)
    # md5sum (platform could have used /usr/bin/digest, or
    # not even bothered with md5'ing a copy command, but
    # this is much more exciting).
    $cmd    = 'setenv PATH ${PATH}:/opt/sfw/bin; copy_remote_files.pl serv_smpp';
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 1 );

    if ( $output =~ /notification files copied successfully to all hosts/ ) {
        print("** Remote Copy ok!\n");
    }
    else {
        print("** Remote Copy problem?\n");
        print($output);
    }

    return;
}

################################################################################
#     FUNCTION: run_dataloader
#
#    ARGUMENTS: STRING  Zone name.
#
#      RETURNS: INT     0 On success
#                       1 On failure
#
#      PURPOSE: Runs the dataloader, (loads tariffing data into shared mem).
################################################################################
sub run_dataloader {
    my $zonename = shift;

    my $cmd    = 'cd $NID_EXTERNAL/bin; data_loader -l all';
    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 1 );

    my $res = $output;

    if ( $res =~ /Data loaded(.+)OK/ ) {
        print("** Data loaded successfully!\n");
    }
    elsif ( $res =~ /Tariff data already up to date/ ) {
        print("** Data already loaded!\n");
    }
    else {
        print("** Data Loader failed. Please Load manually!\n");
        print( "** " . $res . "\n" );
    }

    return;
}

################################################################################
#     FUNCTION: run_cgw_postinstall
#
#    ARGUMENTS: $cgw_version
#
#      RETURNS: INT     0 On success
#                       1 On failure
#
#      PURPOSE: Runs the postinstall of the CGW packages, as we coudlnt run them
#               during package install because Sybase had yet to be installed.
################################################################################
sub run_cgw_postinstall {
	my $cgwVersion = shift;

    print("** Running POSTINSTALL: TINScgwDB package $cgwVersion\n");
    my $cmd    = "/opt/TINScgwDB/$cgwVersion/scripts/postinstall.db.sh";
    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 1 );

    $cmd    = "/opt/TINScgwDB/$cgwVersion/scripts/patch_postinstall.db.sh";
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 1 );

	$cmd    = "cd /opt/TINScgwPP/$cgwVersion/config; sed 's/cgw-1,cgw-2/$zonename/' ChargingConfiguration.xml > newChargingConfiguration.xml;cp newChargingConfiguration.xml ChargingConfiguration.xml";
	$user   = "tecnomen";
	$output = zlogin( $zonename, $user, $cmd, 0 );
	if ( $output != 0 )
	{
		warn("!! Problem modifying ChargingConfiguration.xml!\n");
		#next;
	}

    $cmd    = "/opt/TINScgwPP/$cgwVersion/scripts/postinstall.pp.sh";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 1 );

    $cmd    = "/opt/TINScgwPP/$cgwVersion/scripts/patch_postinstall.pp.sh";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 1 );

    return;
}

################################################################################
#     FUNCTION: load_db
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  Name of database to be installed (SCDR_DB, SI_DB,...)
#               STRING  Path to the install files of the database.
#
#      RETURNS: INT     0 On success
#                       1 On failure
#
#      PURPOSE: Load data into a database using the LoadDB.pl script.
################################################################################
sub load_db {
    my $zonename     = shift;
    my $db           = shift;
    my $db_data_path = shift;

    # Find location of the createdatabases.pl script.
    my $cmd        = '. /.profile; printf %s $TINP_SCRIPTS';
    my $user       = "root";
    my $output     = zlogin( $zonename, $user, $cmd, 1 );
    my $script_dir = $output;
    my $cdb_path   = "";

    if ( $script_dir eq "" ) {
        die("Couldn't find TINP_SCRIPTS!\n");
    }
    else {

        # Add the script to the path.
        $cdb_path = $script_dir . "/loadDB.pl";
    }

    $cmd    = "cd " . $db_data_path . '; ' . $cdb_path . " -Usa -Ppassword " . $db;
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    if ( $output != 0 ) {
        print("** Couldn't Install Database! [$!]");
        return (1);
    }
    else {
        return (0);
    }
}


################################################################################
#     FUNCTION: upgrade_pp_db
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  Path to the upgrade files of the database.
#
#      RETURNS: INT     0 On success
#                       1 On failure
#
#      PURPOSE: Upgrade PP_DB after patch installation.
################################################################################
sub upgrade_pp_db {
    my $zonename     = shift;
    my $upgrade_path = shift;
    my $upgrade_sql  = shift;
    my $user         = "tecnomen";

    my $cmd    = "cd $upgrade_path; isql -Usa -Ppassword -i $upgrade_sql";
    my $output = zlogin( $zonename, $user, $cmd, 0 );

    if ( $output != 0 ) {
        print("** Couldn't upgrade PP_DB with: $cmd\n");
        return (1);
    }
    else {
        return (0);
    }
}


################################################################################
#     FUNCTION: modify_idd
#
#    ARGUMENTS: STRING  Zonename.
#               STRING  Path to the root directory of the zone (in the global
#                       zone).
#               STRING  Path in zone to idd file
#               STRING  Cluster name
#
#      RETURNS: NONE
#
#      PURPOSE: This function modifies the default install.dat file before the
#               postinstall is run.
################################################################################
sub modify_idd {
    my $zonename      = shift;
    my $zone_rel_root = shift;
    my $which_idd     = shift;
    my $cluster       = shift;
    my $cmd              = "";

    print("** MODIFYING: $which_idd\n");

    # Find platform version.
    if ( $InstallType eq "zone" ) {
        $cmd          = "ls " . $zonehome . $zonename . "/root/opt/TINPbase/ |grep -v log";
    } else {
        $cmd          = "ls /opt/TINPbase/ |grep -v log";
    }
    my $tinp_version = `$cmd`;
    chomp($tinp_version);

    if ( $tinp_version eq "" ) {
        die("Couldn't figure out TINP_VERSION!\n");
    }
    my $local_file     = $which_idd;
    my $newtmpl        = $local_file . ".1";
    my $global_file    = $zone_rel_root . $local_file;
    my $global_newtmpl = $zone_rel_root . $newtmpl;

    open( my $IDD, "<", $global_file )    or die("Couldn't open $global_file for reading!\n");
    open( my $OUT, ">", $global_newtmpl ) or die("Couldn't open $global_newtmpl for writing!\n");

    while (<$IDD>) {
        my $line = $_;

        # See if it matches any of them.
        if (/^GLOBAL_ROOT/) {
            $line = "GLOBAL_ROOT=\"/opt/TINUppzone/zone_shares/cluster_" . $cluster . "/global/sdp/\"\n";
        }
        elsif (/^SDP_NFS_IDD_IP/) {
            $line = "SDP_NFS_IDD_IP=\"11.1.51.101\"\n";
        }
        print( $OUT $line );
    }

    close($OUT) or die("Couldn't close $global_newtmpl!\n");
    close($IDD) or die("Couldn't close $global_file!\n");

    copy( $global_file,    $global_file . ".orig" ) or die("Couldn't copy $local_file to $local_file.orig![$!]\n");
    copy( $global_newtmpl, $global_file )           or die("Couldn't copy $global_newtmpl to $local_file![$!]\n");

    return;
}

################################################################################
#     FUNCTION: modify_ctp_etc_hosts
#
#    ARGUMENTS: STRING  Zonename.
#               STRING  Path to the root directory of the zone (in the global
#                       zone).
#
#      RETURNS: NONE
#
#      PURPOSE: This function edits the /etc/hosts file of a CTP, and adds the
#               Additional hostnames to make it "work".
################################################################################
sub modify_ctp_etc_hosts {
    my $zonename      = shift;
    my $zone_rel_root = shift;

    print("** MODIFYING CTP's: /etc/hosts\n");
    my $global_file = $zone_rel_root . "/etc/inet/hosts";
    my $tmp_file    = $zone_rel_root . "/etc/inet/hosts.1";
    my $backup_file = $zone_rel_root . "/etc/inet/hosts.ppzone";

    my $cmd = 'cp ' . $global_file . ' ' . $backup_file;
    print( "** " . $cmd . "\n" );
    my $output = system($cmd);
    if ( $output != 0 ) {
        warn("!! Couldn't Create backup of zones /etc/hosts file!\n");
        return;
    }

    open( my $IN,  "<", $global_file ) or warn("!! Couldn't open /etc/hosts file!\n");
    open( my $OUT, ">", $tmp_file )    or warn("!! Couldn't open tmp /etc/hosts file!\n");
    while (<$IN>) {
        my $line = $_;
        if ( $line =~ /$zonename/ ) {
            chomp($line);
            $line .= " CTP CTP1 SCP SCP1 CCP MD OMC PSP SDP SRP ESN ESN1";
            $line .= " scp-1 ccp-1 ccp-m1 psp-pmgr-pub";
            $line .= " ccp-m1-pub psp-1 srp-1 cgw-1\n";
        }

        print( $OUT $line );
    }

    # Set the ip address for the JTAF_HOST.
    print $OUT "$jtaf_host   JTAF_HOST\n";

    close($OUT) or warn("Couldn't close /etc/hosts file!\n");
    close($IN)  or warn("Couldn't close temporary /etc/hosts file!\n");

    $cmd = 'cp ' . $tmp_file . ' ' . $global_file;
    print( "** " . $cmd . "\n" );
    $output = system($cmd);
    if ( $output != 0 ) {
        warn("!! Couldn't copy modified /etc/hosts file!\n");
        return;
    }

    return;
}

################################################################################
#     FUNCTION: modify_db_tmpl
#
#    ARGUMENTS: STRING  Zonename.
#               STRING  Path to the root directory of the zone (in the global
#                       zone).
#               OBJECT  Config::IniFiles object
#
#      RETURNS: NONE
#
#      PURPOSE: This function modifies the database.dat.tmpl from the TINPtmplt
#               package before it is expanded. The modification reduces the
#               size of the SCDR devices.
################################################################################
sub modify_db_tmpl {
    my $zonename      = shift;
    my $zone_rel_root = shift;
    my $cfg           = shift;
    my $cmd              = "";

    print("** MODIFYING: database.dat.tmpl\n");

    # Find location of scdr data.
    if ( $InstallType eq "zone" ) {
        $cmd = "ls " . $zonehome . $zonename . "/root/opt/TINPtmplt/ |grep -v log";
    } else {
        $cmd = "ls /opt/TINPtmplt/ |grep -v log";
    }
    my $tinp_version = `$cmd`;
    chomp($tinp_version);

    if ( $tinp_version eq "" ) {
        die("Couldn't figure out TINP_VERSION!\n");
    }

    # Only want one dataserver (e.g. No sybase2).
    my $remove_sybase2 = 0;
    if ( $cfg->val( "options", "only_one_dataserver" ) ) {
        $remove_sybase2 = 1;
    }

    my $local_file     = "/global/sdp/tconfig/templates/" . $tinp_version . "/config/database.dat.tmpl";
    my $newtmpl        = $local_file . ".1";
    my $global_file    = $zone_rel_root . $local_file;
    my $global_newtmpl = $zone_rel_root . $newtmpl;

    my @section_data = $cfg->GroupMembers("dbtmpl");
    my @section_list;

    foreach my $header (@section_data) {
        my ($section) = $header =~ /^dbtmpl\s+(.+)/;
        push( @section_list, $section );
    }

    my $regexp = join( "|", @section_list );

    my $block = 0;
    my $vars  = "";
    my $db    = "";

    open( my $DBF, "<", $global_file )    or die("Couldn't open $global_file for reading!\n");
    open( my $OUT, ">", $global_newtmpl ) or die("Couldn't open $global_newtmpl for writing!\n");

    while (<$DBF>) {
        my $line = $_;

        # Look for the start of a db server in the tmpl file.
        if ( $line =~ /\[($regexp)/ ) {
            $block = 1;

            # Find out which one it matched.
            foreach my $sect (@section_list) {
                if ( $line =~ /$sect/ ) {
                    $vars = join( "|", $cfg->Parameters( "dbtmpl " . $sect ) );
                    $db = $sect;
                }
            }
        }

        # If we're don't want sybase2.
        elsif ( $remove_sybase2 && $line =~ /GR_DB_USED/ ) {
            $line           = "NUM_SERVERS         = <?= (strtoupper(\$GR_DB_USED) == 'YES') ? 3 : 1 ?>\n";
            $remove_sybase2 = 0;
        }

        # If we're in a block.
        if ($block) {

            # Check have we reached the end...
            if ( $line =~ /<\? } \?>/ ) {

                # The pp section of database.dat.tmpl is
                # different to the rest.
                if ( ( $db =~ /PP_DB/ ) && $block == 1 ) {

                    # Keep going in this block!
                    # This will affect the non-ctp section
                    # of the pp server but I don't want to
                    # change the actual database.dat.tmpl
                    $block = 2;
                }
                elsif ( ( $db =~ /CC_DB/ ) && $block == 1 ) {

                    # When they say its a template file,
                    # what the actually mean is: not a
                    # template file, since every bloody
                    # section is formatted differently,
                    # even though it contains the same
                    # information!!!!!!!!!!!!!!!!!!!!!!
                    $block = 3;
                }
                elsif ( ( $db =~ /master/ ) && $block == 1 ) {
                    $block = 4;
                }
                elsif ( ( $db =~ /sybprocs/ ) && $block == 1 ) {
                    $block = 5;
                }
                else {
                    $block = 0;
                }
            }

            # Check are we on a line with a parameter that needs
            # changing.
            if ( $line =~ /^($vars)/ ) {
                foreach my $param ( $cfg->Parameters( "dbtmpl " . $db ) ) {
                    if ( $line =~ /$param/ ) {
                        $line = $param . "=" . $cfg->val( "dbtmpl " . $db, $param ) . "\n";
                    }
                }
            }
        }
        print( $OUT $line );
    }

    close($OUT) or die("Couldn't close $global_newtmpl!\n");
    close($DBF) or die("Couldn't close $global_file!\n");

    copy( $global_file,    $global_file . ".orig" ) or die("Couldn't copy $local_file to $local_file.orig![$!]\n");
    copy( $global_newtmpl, $global_file )           or die("Couldn't copy $global_newtmpl to $local_file![$!]\n");

    return;
}

################################################################################
#     FUNCTION: modify_SAprofile
#
#    ARGUMENTS: STRING  Zonename.
#               STRING  Path to the root directory of the zone (in the global
#                       zone).
#               OBJECT        Config::IniFiles object
#
#      RETURNS: NONE
#
#      PURPOSE: This function modifies the SAprofile.imf file from the TINPtmplt
#               package before it is expanded in TINPbase.
################################################################################
sub modify_SAprofile {
    my $zonename      = shift;
    my $zone_rel_root = shift;
    my $cfg           = shift;
    my $cmd              = "";

    print("** MODIFYING: SAprofile.imf\n");

    # Find location of scdr data.
    if ( $InstallType eq "zone" ) {
        $cmd          = "ls " . $zonehome . $zonename . "/root/opt/TINPtmplt/ |grep -v log";
    } else {
        $cmd          = "ls /opt/TINPtmplt/ |grep -v log";
    }
    my $tinp_version = `$cmd`;
    chomp($tinp_version);

    if ( $tinp_version eq "" ) {
        die("Couldn't figure out TINP_VERSION!\n");
    }
    my $local_file     = "/global/sdp/tconfig/templates/" . $tinp_version . "/config/SAprofile.imf";
    my $newtmpl        = $local_file . ".1";
    my $global_file    = $zone_rel_root . $local_file;
    my $global_newtmpl = $zone_rel_root . $newtmpl;

    my @change_parameters = $cfg->Parameters("SAprofile");

    # We're going to use the parameters in a regexp.
    my $param_list = join( "|", @change_parameters );
    $param_list = "(" . $param_list . ")";

    open( my $SAP, "<", $global_file )    or die("Couldn't open $global_file for reading!\n");
    open( my $OUT, ">", $global_newtmpl ) or die("Couldn't open $global_newtmpl for writing!\n");

    while (<$SAP>) {
        my $line = $_;

        # See if it matches any of them.
        if (/^$param_list/) {

            # Find out which one it matched.
            foreach my $param (@change_parameters) {
                if ( $line =~ /$param/ ) {
                    $line = $param . "=" . $cfg->val( "SAprofile", $param ) . "\n";
                    last;
                }
            }
        }
        print( $OUT $line );
    }

    close($OUT) or die("Couldn't close $global_newtmpl!\n");
    close($SAP) or die("Couldn't close $global_file!\n");

    copy( $global_file,    $global_file . ".orig" ) or die("Couldn't copy $local_file to $local_file.orig![$!]\n");
    copy( $global_newtmpl, $global_file )           or die("Couldn't copy $global_newtmpl to $local_file![$!]\n");

    # Workaround for issue with TINPtmplt not installing correctly.
	# Basically, if Prepaid_xxx.conf does not exist, then the installation craps out, rather than exiting gracefully.
    copy( $zone_rel_root . '/global/sdp/tconfig/templates/5.20/config/Prepaid_460.conf', $zone_rel_root . '/global/sdp/tconfig/templates/5.20/config/Prepaid_461.conf' );
    copy( $zone_rel_root . '/global/sdp/tconfig/templates/5.20/config/Prepaid_460.conf', $zone_rel_root . '/global/sdp/tconfig/templates/5.20/config/Prepaid_480.conf' );

    return;
}

################################################################################
#     FUNCTION:  initialise_sisql
#
#    ARGUMENTS:  STRING  Zone name.
#
#      RETURNS:  NONE
#
#      PURPOSE:  Initialises the sisql database
################################################################################
sub initialise_sisql {
    my $zonename = shift;

    my $cmd    = 'sisql_init.sh password';
    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 0 );

    if ( $output != 0 ) {
        die("Couldn't initialise the sisql database! [$!]\n");
    }

    return;
}

################################################################################
#     FUNCTION: install_db
#
#    ARGUMENTS:  STRING  Zone name.
#                STRING  Name of database to be installed (SCDR_DB, SI_DB,...)
#                STRING  Path to the install files of the database.
#                STRING  type for the -A switch
#
#      RETURNS:  INT     0 On success
#                        1 On failure
#
#      PURPOSE:  Creates a database using the CreateDatabases.pl script.
################################################################################
sub install_db {
    my $zonename     = shift;
    my $db           = shift;
    my $db_data_path = shift;
    my $type         = shift;

    # Find location of the createdatabases.pl script.
    my $cmd        = '. /.profile; printf %s $TINP_SCRIPTS';
    my $user       = "root";
    my $output     = zlogin( $zonename, $user, $cmd, 1 );
    my $script_dir = $output;
    my $cdb_path   = "";

    if ( $script_dir eq "" ) {
        die("Couldn't find TINP_SCRIPTS!\n");
    }
    else {

        # Add the script to the path.
        $cdb_path = $script_dir . "/CreateDatabases.pl";
    }

    $cmd    = "cd " . $script_dir . '; ' . $cdb_path . " -q -A " . $type . " -D " . $db . " -P " . $db_data_path;
    $user   = "tecnomen";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    if ( $output != 0 ) {
        print("** Couldn't Install Database! [$!]");
        return (1);
    }
    else {
        return (0);
    }
}

################################################################################
#     FUNCTION: link_log_file
#
#    ARGUMENTS:  STRING  Zone name.
#                STRING  Zones local path
#                STRING  Global path to dir
#                STRING  (OPTIONAL) Log file name
#
#      RETURNS:  NONE
#
#      PURPOSE:  Creates a softlink to log files
################################################################################
sub link_log_file {
    my $log_share_dir = shift;
    my $path          = shift;
    my $global_path   = shift;
    my $file          = shift;

    my $abs_file_path = "";

    if ( !defined($file) ) {
        $file = "";

        # Have to figure out the log file name.
        my @list = glob("$global_path$path/*.log");
        if ( !@list ) {
            warn("!! Couldn't find log file at $global_path$path!\n");
            return;
        }
        my ( $dir, $rest );
        ( $file, $dir, $rest ) = fileparse( $list[0] );
        $abs_file_path = $path . "/" . $file;
    }
    else {
        $abs_file_path = $path . "/" . $file;
    }

    copy( $global_path . $abs_file_path, $log_share_dir . "/" . $file ) or warn("!! Couldn't copy $file! $global_path$abs_file_path $log_share_dir/$file [$!]\n");

    return;
}

################################################################################
#     FUNCTION: install_sybase
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  Path to Sybase installation binaries.
#               STRING  Zone path
#               STRING  Type of machine (ctp..)
#
#      RETURNS: INT     0 on success
#                       1 on failure
#
#      PURPOSE: Installs sybase (and patches) from sybase deliverables
################################################################################
sub install_sybase {
    my $zd = shift;

    # Find out where csi is installed.
    my $cmd      = '. /.profile; printf %s $TINP_SCRIPTS';
    my $user     = "root";
    my $output   = zlogin( $zd->{'zonename'}, $user, $cmd, 1 );
    my $csi_path = $output;

    if ( $csi_path eq "" ) {
        die("Couldn't find csi script!\n");
    }
    else {
        $csi_path .= "/csi";
    }

    $cmd = $csi_path . " -d " . $zd->{'lz_sybase_main_dir'} . " -T -q -n";

    # Older versions of csi (<5.10), do not have an automagic install.
    # command switch, so run expect script instead.
    if ( $zd->{'old_plat'} ) {
        run_csi_with_expect( $zd->{'zonename'}, $cmd );
    }
    else {
        $user = "root";
        $output = zlogin( $zd->{'zonename'}, $user, $cmd, 0 );
        if ( $output != 0 ) {
            print("** Error occurred when installing sybase (csi)!");
            return (1);
        }
    }

    if ( !$zd->{'old_plat'} ) {

        # Create sybase licence file, modify dserver properties.
        # and restart.
        if ( install_sybase_licence( $zd->{'zonename'}, $zd->{'gz_path_to_lz_root'}, $zd->{'plat_type'} ) == 2 ) {

            # If no dataservers were found, return.
            return (1);
        }
    }

    # Wait for the servers start up correctly.
    my $loop = 1;
    my $wait = 0;
    print("** Waiting for Sybase to come back online:\n");
    while ($loop) {
        $cmd    = 'isql -Usa -Ppassword -i /dev/null';
        $user   = "sybase";
        $output = zlogin( $zd->{'zonename'}, $user, $cmd, 1 );
        if ( $output =~ /ct_connect/ ) {
            if ( $wait > 90 ) {

                # We've waited enough, its probably
                # not coming back...
                print(" no joy!\n");
                die("!! Sybase didn't come back up!\n");
            }
            else {

                # Can't connect just yet
                print(".");
                ++$wait;
                sleep(2);
            }
        }
        else {
            $loop = 0;
            print(" ok\n");
        }
    }

    # Edit the number of user connections.
    $cmd    = 'printf "sp_configure %s, 106292\ngo\nsp_configure %s, 100\ngo" \"max\ memory\" \"number\ of\ user\ connections\" > /tmp/ppzoneuserconn.sql';
    $user   = "sybase";
    $output = zlogin( $zd->{'zonename'}, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't create sql file for num of user connections!\n");
        return (1);
    }
    $cmd    = 'isql -Usa -Ppassword -i /tmp/ppzoneuserconn.sql -o /tmp/out.ppzoneuserconn';
    $user   = "sybase";
    $output = zlogin( $zd->{'zonename'}, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't Modify the number of user connections!\n");
    }

    # Create links to the Sybase run configurations used by the rc2.d K40sybase
    # script on reboot.
    $cmd =
        'ln -s /opt/sybase/ASE-15_0/install/RUN_SYBASE1 '
      . '/opt/sybase/ASE-15_0/install/RUN_SYBASE; '
      . 'ln -s /opt/sybase/ASE-15_0/install/RUN_SYB_BACKUP1 '
      . '/opt/sybase/ASE-15_0/install/RUN_SYB_BACKUP;';

    $user   = "sybase";
    $output = zlogin( $zd->{'zonename'}, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't create Sybase configuration symlinks!\n");
    }

    return (0);
}

################################################################################
#     FUNCTION: run_csi_with_expect
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  csi command
#
#      RETURNS: 0 on success,
#
#      PURPOSE: Runs csi using expect to supply answers.
################################################################################
sub run_csi_with_expect {
    my $zonename = shift;
    my $csi_cmd  = shift;

    require Expect;

    my $cmd = '/usr/sbin/zlogin ' . $zonename . ' \'' . $csi_cmd . '\'';

    #my $cmd = q{/usr/sbin/zlogin ctp-1-446 '/opt/TINPbase/5.00/scripts/csi -T -d /export/share/sybase125/ase125'};
    my @params = ();

    my $exp = new Expect;
    $exp->raw_pty(1);
    $exp->spawn( $cmd, @params ) or die "Cannot spawn $cmd: $!\n";

    my @list = (
        "Check for sybase account and create it if not present",
        "Generate database.dat from template file",
        "Expand sybase silent installation config and server resource files from templates",
        "Change ownership of all devices for all databases to Sybase",
        "Perform sybase install",
        "Create sybase servers needed - using resource files",
        "Set passwords on sybase servers",
        "Run sybase install verification checks",
        "Alias SYBASE to SYBASE1 in interfaces file",
        "Alias SYBASE_PICES to SYBASE in interfaces file",
        "Region 1 is PICES master region. Probe for servers there",
        "Set entry for SYBASE_PICES_MASTER on",
        "Update permissions on sybase directory"
    );

    my @last       = ( '-re', 'Reboot machine now' );
    my @med_delay  = ( '-re', 'Modify the /etc/system file with the addition parameters needed for sybase' );
    my @long_delay = ( '-re', 'Create sybase servers needed - using resource files' );

    my @short_delay = ();
    foreach my $line (@list) {
        push( @short_delay, "-re" );
        push( @short_delay, $line );
    }

    my $go = 1;

    while ($go) {
        if ( defined( $exp->expect( 15, @last ) ) ) {
            print "NO\n";
            $exp->send("n\n");
            $go = 0;
        }
        elsif ( defined( $exp->expect( 10, @short_delay ) ) ) {
            print "YES\n";
            print localtime() . "\n";
            $exp->send("\n");
        }
        elsif ( defined( $exp->expect( 25, @med_delay ) ) ) {
            print " YES\n";
            print localtime() . "\n";
            $exp->send("\n");
        }
        elsif ( defined( $exp->expect( 300, @long_delay ) ) ) {
            print "  YES\n";
            print localtime() . "\n";
            $exp->send("\n");
        }
    }

    $exp->soft_close();

    return;
}

################################################################################
#     FUNCTION: install_sybase_licence
#
#    ARGUMENTS: STRING  Zone name.
#       STRING  Path to root of zone
#       STRING  Platform type (ctp...)
#
#      RETURNS: 0 on success,
#               1 on internal failure,
#               2 when unable to find a running dataserver.
#
#      PURPOSE: Adds the sybase licence file, modify the server properties file
#               and restart all servers.
################################################################################
sub install_sybase_licence {
    my $zonename      = shift;
    my $rootpath      = shift;
    my $platform_type = shift;
    my $sybdir        = "";

    if ( $platform_type eq "ctp" ) {
        $sybdir = "/opt/sybase";
    }
    else {
        $sybdir = "/global/sdp/sybase";
    }

    # Sybase licence directory.
    my $licdir = $sybdir . "/SYSAM-2_0/licenses";

    my $cmd = 'cp /opt/TINUppzone/config/TINUppzone.lic ' . $rootpath . '/' . $licdir;
    print( "** " . $cmd . "\n" );
    my $output = system($cmd);
    if ( $output != 0 ) {
        warn("!! Couldn't write licence file [$licdir/TINUppzone.lic!]\n");
        return;
    }

    # Make sure that when the sybase licence file is copied over, that
    # sybase has permissions to read it!
    $cmd = "chown sybase:super $licdir/TINUppzone.lic";
    my $user = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't change owner of the $licdir/TINUppzone.lic to sybase!\n");
        return (1);
    }

    # Figure out what dataservers are running.
    $cmd    = "pargs `pgrep dataserver` 2>&1";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 1 );

    if ( $output =~ /usage/ ) {
        warn("!! No dataservers found! Check sybase log in zone's /tmp!\n");
        return (2);
    }

    my @dservers = $output =~ /argv\[\d+\]: -s(.+)/g;

    # Create the shutdown sql file.
    $cmd    = 'printf "shutdown\ngo" > /tmp/ppzoneshut.sql';
    $user   = "sybase";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        warn("!! Couldn't copy sql shutdown file!\n");
        return (1);
    }

    # Lets stop, edit .properties file, and restart each dataserver.
    foreach my $dataserver (@dservers) {

        # Shut it down!.
        $cmd    = 'isql -Usa -Ppassword -S' . $dataserver . ' -i /tmp/ppzoneshut.sql -o /tmp/out.ppzoneshut.' . $dataserver;
        $user   = "sybase";
        $output = zlogin( $zonename, $user, $cmd, 0 );
        if ( $output != 0 ) {
            warn("!! Couldn't shutdown $dataserver!\n");
            next;
        }

        # Modify the dataserver .properites file.
        $cmd    = "cd $sybdir/ASE-15_0/sysam/; sed 's/PE=DE/PE=EE/' $dataserver.properties > $dataserver.p;cp $dataserver.p $dataserver.properties";
        $user   = "root";
        $output = zlogin( $zonename, $user, $cmd, 0 );
        if ( $output != 0 ) {
            warn("!! Problem rewriting $dataserver.properties file!\n");
            next;
        }

        # Restart server.
        $cmd    = "cd $sybdir/ASE-15_0/install; ./startserver -f RUN_" . $dataserver . " 2>&1 &";
        $user   = "sybase";
        $output = zlogin( $zonename, $user, $cmd, 0 );
        if ( $output != 0 ) {
            warn( "!! Couldn't restart " . $dataserver . "!\n" );
            next;
        }
    }
    return (0);
}

################################################################################
#     FUNCTION: install_zone_pkg
#
#    ARGUMENTS: STRING  Name of zone
#       STRING  Platform Type
#       STRING  Package name
#       STRING  Name of package instance
#       STRING  Response file identifier.
#       STRING  Path to where the lofs share is shared from in global
#               zone.
#       STRING  Path of where the lofs share is shared to, in the zone.
#       STRING  Response file information.
#       INT     0 if request script exists, 1 otherwise.
#
#      RETURNS: NONE
#
#      PURPOSE: Installs a package in a zone
################################################################################
sub install_zone_pkg {
    my $zd            = shift;
    my $platform_type = shift;
    my $package_name  = shift;
    my $package_inst  = shift;
    my $resp_file     = shift;
    my $resp_data     = shift;
    my $norequest     = shift;

    # Create the response file.
    if ( !defined($resp_data) ) {
        $resp_data = "";
    }

    my $caps_platform_type = uc($platform_type);

    $resp_data =~ s/=(ctp|sdp|scp|psp|srp|ccp)/=$platform_type/;
    $resp_data =~ s/=(CTP|SDP|SCP|PSP|SRP|CCP)/=$caps_platform_type/;

    open( my $RESP, ">", $zd->{'gz_share_dir'} . "/" . $resp_file ) or die("Couldn't create response file: $resp_file [$!]\n");
    print( $RESP $resp_data );
    close($RESP) or die("Couldn't create a response file: $resp_file\n");

    print( "*" x 80 );
    print("\n** $package_inst ($package_name)\n");
    print( "*" x 80 );
    print("\n");

    my $pkgadd_cmd = "";

    if ($norequest) {
        $pkgadd_cmd = '/usr/sbin/pkgadd -G -d ' . $zd->{'lz_share_dir'} . '/' . $package_name . ' ' . $package_inst;
    }
    else {
        $pkgadd_cmd =
            '/usr/sbin/pkgadd -G -d '
          . $zd->{'lz_share_dir'} . '/'
          . $package_name
          . ' -n -a '
          . $zd->{'lz_share_dir'}
          . '/install.admin -r '
          . $zd->{'lz_share_dir'} . '/'
          . $resp_file . ' '
          . $package_inst;
    }

    my $cmd    = $pkgadd_cmd;
    my $user   = 'root';
    my $output = zlogin( $zd->{'zonename'}, $user, $cmd, 0 );
    if ( $output != 0 ) {
        die("Pkgadd command failed for package instance: $package_inst!\n");
    }

    return;
}

################################################################################
#     FUNCTION: check_previously_installed
#
#    ARGUMENTS: STRING  Name of zone to be checked.
#
#      RETURNS: NONE
#
#      PURPOSE: Checks whether a particular build has already been installed.
################################################################################
sub check_previously_installed {
    my $zonename = shift;

    my $cmd    = "/usr/sbin/zoneadm -z $zonename list";
    my $result = `$cmd`;
    chomp($result);
    if ( $result eq $zonename ) {
        die("This Zone name already exists! [$zonename]\n");
    }

    return;
}

################################################################################
#     FUNCTION: create_share_directory
#
#    ARGUMENTS: STRING  Name of path to be created.
#
#      RETURNS: STRING  Path to the log directory.
#
#      PURPOSE: Creates a directory with the same name as the zone off of the
#               Designated share directory. This directory will be used to
#               hold the build packages.
################################################################################
sub create_share_directory {
    my $share_dir = shift;
    my $log_dir   = $share_dir . "/logs";

    # Octal!
    my $mode = oct(755);

    print("** Share directory: $share_dir\n");

    # Create the share directory.
    #system( "mkdir -p " . $log_dir ) == 0 or die("Couldn't create the share directory: $log_dir! [$!]\n");
    system( "mkdir -p " . $log_dir );

    # Set permissions.
    chmod( $mode, $share_dir );
    chmod( $mode, $log_dir );

    return ($log_dir);
}

################################################################################
#     FUNCTION: create_daily_zone
#
#    ARGUMENTS: STRING  Name of zone to be created.
#       STRING  Parent directory of the zonepath of the new zone.
#       STRING  Zonepath of the basezone.
#       STRING  Path to where the lofs share is shared from in global
#               zone.
#       STRING  Path of where the lofs share is shared to, in the zone.
#
#      RETURNS: NONE
#
#      PURPOSE: Creates a zone by cloning the base-zone and modifying it with
#               the daily packages parameters.
################################################################################
sub create_daily_zone {
    my $zd              = shift;
    my $clone_zone_type = shift;
    my $ip_ref          = shift;

    # Create the new zone configuration.
    my $zonecfg_create =
        "/usr/sbin/zonecfg -z "
      . $zd->{'zonename'}
      . " \"create\;"
      . "set zonepath="
      . $zd->{'gz_zone_home'} . "\;"
      . "set autoboot=true\;"
      . "set limitpriv=\"default,dtrace_proc,dtrace_user\"\;"
      . "add fs\;"
      . "set special="
      . $zd->{'gz_share_dir'} . "\;"
      . "set dir="
      . $zd->{'lz_share_dir'} . "\;"
      . "set type=lofs\;"
      . "add options [rw,nodevices]\;" . "end;"
      . "add fs\;"
      . "set special="
      . $zd->{'gz_sybase_dir'} . "\;"
      . "set dir="
      . $zd->{'lz_sybase_dir'} . "\;"
      . "set type=lofs\;"
      . "add options [ro,nodevices]\;" . "end;"
      . "add fs\;"
      . "set special="
      . $zd->{'gz_cap2sim_dir'} . "\;"
      . "set dir="
      . $zd->{'lz_cap2sim_dir'} . "\;"
      . "set type=lofs\;"
      . "add options [ro,nodevices]\;" . "end\"";

    # Building a full zone, get rid of inherit pkg dirs!
    if ( $clone_zone_type eq "full-zone" ) {

        # Get rid of the closing quotes and and a command terminator.
        chop($zonecfg_create);
        $zonecfg_create .= "\;";
        $zonecfg_create .= "remove inherit-pkg-dir dir=/lib\;" . "remove inherit-pkg-dir dir=/platform\;" . "remove inherit-pkg-dir dir=/sbin\;" . "remove inherit-pkg-dir dir=/usr\;";
    }

    # Support for ip addresses.
    if (@$ip_ref) {

        # Get rid of the closing quotes and and a command terminator.
        chop($zonecfg_create);
        $zonecfg_create .= "\;";

        # Add the IP address.
        $zonecfg_create .= "add net\;" . "set address=$ip_ref->[0]\;" . "set physical=$ip_ref->[1]\;" . "end\"";
    }

    print( "** " . $zonecfg_create . "\n" );
    system($zonecfg_create) == 0 or die( "Couldn't zonecfg the zone " . $zd->{'zonename'} . "!\n" );

    # Clone the base-zone.
    my $zone_clone = "/usr/sbin/zoneadm -z " . $zd->{'zonename'} . " clone " . $clone_zone_type;
    print( "** " . $zone_clone . "\n" );
    system($zone_clone) == 0 or die("Couldn't clone the zone [$clone_zone_type]!\n");

    # Create /etc/sysidcfg to automate first run.
    create_sysidcfg( $zd->{'zonename'}, $zd->{'gz_zone_home'}, $ip_ref );

    # Create /etc/.nfs4inst_state.domain.
    my $touch_nfs = "touch " . $zd->{'gz_zone_home'} . "/root/etc/.NFS4inst_state.domain";
    print( "** " . $touch_nfs . "\n" );
    system($touch_nfs) == 0 or warn("!! Couldn't create the .NFS4inst_state.domain file, you may have to log onto the Zone Console and complete config manually!\n");

    # Create networking files (/etc/resolv.conf, /etc/nsswitch.conf, /etc/defaultrouter).
    configure_network( $zd->{'zonename'}, $zd->{'gz_zone_home'}, $ip_ref->[0] );

    # Boot zone.
    my $zone_boot = "/usr/sbin/zoneadm -z " . $zd->{'zonename'} . " boot";
    print( "** " . $zone_boot . "\n" );
    system($zone_boot) == 0 or die( "Couldn't boot the zone: " . $zd->{'zonename'} . "!\n" );

    # Wait for the boot to fully finish.
    print("** Waiting for Zone to boot up: ");
    my $loop = 1;
    while ($loop) {
        my $cmd    = "svcs -Ho state svc:/milestone/sysconfig:default 2>&1";
        my $user   = "root";
        my $output = zlogin( $zd->{'zonename'}, $user, $cmd, 1 );

        if ( $output =~ /online/ ) {
            $loop = 0;
        }
        elsif ( $output =~ /only to running/ ) {
            print($output);
        }
        else {
            print(".");
            ++$loop;
        }

        if ( $loop > 180 ) {
            print("\n!! Zone doesn't appear to be have completed its sysid!!\n!!Moving on.\n");
            last;
        }
        sleep(3);
    }
    print("\n");

    # If we're installing a full root zone we'll have to configure a few things
    # (libsbgse2.so, Config::IniFiles, /usr/local/bin/perl softlink).
    if ( $clone_zone_type eq "full-zone" ) {
        configure_full_zone( $zd->{'zonename'}, $zd->{'gz_zone_home'} );
    }

    return;
}

################################################################################
#     FUNCTION: configure_full_zone
#
#    ARGUMENTS: STRING  Zonename
#       STRING  Path to zoneroot on global zone.
#
#      RETURNS: NONE
#
#      PURPOSE: Performs tweaks that allow Prepaid software to configure
#               successfully.
################################################################################
sub configure_full_zone {
    my $zonename = shift;
    my $zoneroot = shift;

    # Copy over the sybase shared library.
    my $cp_syblib = "cp /opt/TINUppzone/3rdParty/libsbgse2.so $zoneroot/root/usr/lib/64/";
    print( "** " . $cp_syblib . "\n" );
    system($cp_syblib) == 0 or die("Couldn't copy libsbgse2.so into full root zone!\n");

    # Link /usr/local/bin/perl to /usr/bin/perl.
    my $cmd    = "mv /usr/local/bin/perl /usr/local/bin/perl.stupid";
    my $user   = "root";
    my $output = zlogin( $zonename, $user, $cmd, 0 );

    $cmd    = "mkdir -p /usr/local/bin";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    $cmd    = "ln -s /usr/bin/perl /usr/local/bin/perl";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    # Install Config::IniFiles.
    my $cp_configini = "cp /opt/TINUppzone/3rdParty/Config-IniFiles-2.39.tar.gz $zoneroot/root/tmp";
    print( "** " . $cp_configini . "\n" );
    system($cp_configini) == 0 or die("Couldn't copy Config-IniFiles into full root zone!\n");

    # Unzip.
    $cmd    = "gunzip /tmp/Config-IniFiles-2.39.tar.gz";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    # Untar.
    $cmd    = "tar -xf /tmp/Config-IniFiles-2.39.tar";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );
    if ( $output != 0 ) {
        die("Couldn't untar Config-IniFiles!\n");
    }

    # Build the makefile.
    $cmd    = "cd Config-IniFiles-2.39; /usr/bin/perl Makefile.PL";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    # Run make.
    $cmd    = "cd Config-IniFiles-2.39; /usr/sfw/bin/gmake";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    # Run make install.
    $cmd    = "cd Config-IniFiles-2.39; /usr/sfw/bin/gmake install";
    $user   = "root";
    $output = zlogin( $zonename, $user, $cmd, 0 );

    return;
}

################################################################################
#     FUNCTION: create_sysidcfg
#
#    ARGUMENTS: STRING  Zonename
#       STRING  Path to zoneroot on global zone.
#
#      RETURNS: NONE
#
#      PURPOSE: Creates the sysidcfg for the zone, to automate machine setup.
################################################################################
sub create_sysidcfg {
    my $zonename = shift;
    my $zoneroot = shift;
    my $ip_ref   = shift;

    my $network_interface = "";

    if (@$ip_ref) {

        # Choose a (default) default route.
        my $default_route = $ip_ref->[0];
        $default_route =~ s/\.\d{1,3}$/.1/;

        # Set out the network interface.
        $network_interface = "network_interface=PRIMARY {hostname=$zonename ip_address=" . $ip_ref->[0] . " netmask=255.255.255.0 protocol_ipv6=no default_route=$default_route}";
    }
    else {
        $network_interface = "network_interface=NONE {hostname=$zonename}";
    }

    my $sysid = <<THERE;
system_locale=C
terminal=dtterm
$network_interface
timeserver=localhost
security_policy=NONE
service_profile=open
name_service=NONE
nfs4_domain=dynamic
timezone=Eire
root_password="boajrOmU7GFmY"
THERE

    open( my $SYSIDCFG, ">", $zoneroot . "/root/etc/sysidcfg" ) or warn("!! Couldn't create sysidcfg, You may have to log onto Zone Console and compelete config manually!\n");
    print( $SYSIDCFG $sysid );
    close($SYSIDCFG) or warn("Couldn't close sysidconfig file!\n");

    return;
}

################################################################################
#     FUNCTION: set_zonename
#
#    ARGUMENTS: STRING  Contains contents of command line switch for naming the
#                       Zone. N.B. This may not be defined!
#
#      RETURNS: STRING  The zonename.
#
#      PURPOSE: Figures out the correct zonename.
################################################################################
sub set_zonename {
    my $name     = shift;
    my $zonename = "";

    if ( defined($name) ) {
        $zonename = $name;
    }
    else {
        my ( $year, $month, $day, $hour, $min, $sec ) = (localtime)[ 5, 4, 3, 2, 1, 0 ];
        my $timestamp = sprintf( "%04d%02d%02d%02d%02d%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec );

        $zonename = "ctp-1-" . $timestamp;
    }

    return ($zonename);
}

################################################################################
#     FUNCTION: get_packages
#
#    ARGUMENTS: STRING  Filename of config file containing package information.
#
#      RETURNS: OBJECT  Config::IniFiles object populated with data from config
#                       file.
#
#      PURPOSE: Fetches the packages listed in the configuration file.
################################################################################
sub get_packages {
    my $config_file = shift;
    my $pkg_dir     = shift;
    my $cfg         = new Config::IniFiles( -file => $config_file );
    my @packages    = $cfg->GroupMembers("package");

    # Create the package directory.
    system( "mkdir -p " . $pkg_dir ) == 0 or die("Couldn't create the package directory: $pkg_dir! [$!]\n");

    my $fetch_tool_log = $pkg_dir . "/wget.log";

    # Keep a track of previously fetched files. No point in getting same
    # package twice.
    my @already_fetched = ();

    foreach my $package (@packages) {

        # If this is a patch we need to keep track of how many patches
        # there are for the package in the original packages configuration.
        if ( $package =~ /package\s+patch\s+(\w+)/ ) {
            my $package_of_patch = "package " . $1;
            my $num_patch = $cfg->val( $package_of_patch, "num_patch" );
            ++$num_patch;

            # Set the value in the original package to be the total
            # number of patches.
            $cfg->newval( $package_of_patch, "num_patch", $num_patch );

            # Set the value in the patch to be its order number.
            $cfg->newval( $package, "num_patch", $num_patch );
        }

        my $location = $cfg->val( $package, 'location' );
        my ( $pkg_file, $build_dir, $tmp ) = fileparse($location);

        # Check this package against previously fetched packages.
        if ( !map( /$pkg_file/, @already_fetched ) ) {
            if ( $location =~ /^http/ ) {
                my $fetch_tool = "/usr/sfw/bin/wget";
                my $fetch_cmd  = $fetch_tool . " -nc -a $fetch_tool_log -P $pkg_dir " . $location;
                print( "** HTTPing package from " . $location . "\n" );
                system($fetch_cmd) == 0 or die("Couldn't retrieve the package!\n");
            }
            else {
                print("** Copying package from: $location\n");
                copy( $location, $pkg_dir ) or die("Couldn't copy the package [$!]\n");
            }
        }
    }
    print("** All packages retrieved!\n");
    uncompress_packages($pkg_dir);

    return ($cfg);
}

################################################################################
#     FUNCTION: uncompress_packages
#
#    ARGUMENTS: STRING  Relative Directory
#
#      RETURNS: NONE
#
#      PURPOSE: Uncompresses the packages.
################################################################################
sub uncompress_packages {
    my $dir  = shift;
    my @list = glob("packages/*");

    foreach my $pkg (@list) {
        if ( $pkg =~ /\.(Z|gz)$/ ) {
            system( "/bin/gunzip " . $pkg ) == 0 or die("Couldn't gunzip file: $pkg!\n");
        }
        elsif ( $pkg =~ /\.bz2/ ) {
            system( "/usr/bin/bunzip2 " . $pkg ) == 0 or die("Couldn't bunzip2 file: $pkg!\n");
        }
    }

    return;
}


################################################################################
#     FUNCTION: install_default_ini
#
#    ARGUMENTS: STRING  zone name.
#             : STRING  ini file name.
#
#      RETURNS: NONE
#
#      PURPOSE: Copy patch ini.default over base ini files auch as pp.ini.
################################################################################
sub install_default_ini {

    my $zonename = shift;
    my $ini_file = shift;

    my $cmd = qq(
      cp \$NID_CONFIG/$ini_file         \$NID_CONFIG/$ini_file.base;
      cp \$NID_CONFIG/$ini_file.default \$NID_CONFIG/$ini_file
     );

    my $user = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 0 );

    if ( $output != 0 ) {
        warn("** Couldn't upgrade PP_DB with: $cmd\n");
        return (1);
    }
    else {
        return (0);
    }

}


################################################################################
#     FUNCTION: install_jtaf
#
#    ARGUMENTS: STRING  jtaf_host IP address.
#             : STRING  optional run command.
#
#      RETURNS: NONE
#
#      PURPOSE: Retrieves and optionally runs JTAF regression tests
################################################################################
sub install_jtaf {
    my $ip = shift;
    my $run_cmd = shift || '';

    my $cmd = 'source /net/jupiter/swdev/ngc/scripts/envNGC.csh;' .
              'svn co --username tecnomen --password tecnomen http://saturn/svnrepos/tools/regression_testing/ regression;' .
              'cd regression;';

    if ( $run_cmd eq 'run' ) {
      $cmd    .= "./kickoff_tests.sh -R -f RT/TINScgwPP-1000059.txt";
      print("** Running regression:\n");
    }
    else {
#      $cmd    .= "./kickoff_tests.sh -t $ip -v " . $dir_version . " -i";
      print("** Nothing to do here.\n");
#      print("** To run regression use the following command\n");
#     print("   ./kickoff_tests.sh -t $ip -v " . $dir_version . " -f pp470.txt  -l cap2 -r\n");
    }

    my $user   = "tecnomen";
    my $output = zlogin( $zonename, $user, $cmd, 0 );

    if ( $output != 0 ) {
        warn( "!! Wasn't able to Run regression\n" );
    }
    else {
        print( "** Regression run. Look at results to verify.\n" );
    }

    return;
}


################################################################################
#     FUNCTION: run_postinstall_script
#
#    ARGUMENTS: STRING  Zone name.
#               STRING  Script to run.
#               STRING  User to run as. Optional. Default 'tecnomen'.
#               STRING  Path to copy to and run from. Optional. Default '/tmp'.
#               STRING  Args to the script. Optional. Default ''.
#
#      RETURNS: INT     0 On success
#                       1 On failure
#
#      PURPOSE: Run a user defined script after installation.
################################################################################
sub run_postinstall_script {
    my $ip = shift;
    my $zonename    = shift;
    my $script      = shift;
    my $user        = shift || 'tecnomen';
    my $destination = shift || '/tmp';
    my $args        = shift || '';
	my $regression_file = 'test_file/regression.txt';

    my $zone_path  =  $zonehome . $zonename . '/root' . $destination;
    my $script_dir = '../scripts';

    if ( !-e "$script_dir/$script" ) {
        warn( "!! Script $script not found in $script_dir\n" );
        return;
    }
	if ( my $temp_regression_file = $cfg->val( "options", "regression_file" ) ) {
		#my $cmd = "ls RT/".$temp_regression_file;
		#    system( $cmd) == 0 or break();

		$regression_file = "RT/".$temp_regression_file;
    }

    # Copy the postinstall script into the destination directory and make it executable.
    my $cmd = "cp $script_dir/$script $zone_path; " . "chmod a+x $zone_path/$script; " . "chown $user $zone_path/$script";

    print "zonecmd is " . $cmd . ".\n";
    system( $cmd) == 0 or warn( "!! Couldn't run command '$cmd'\n" );
    if ($script eq 'install_jtaf.sh')
    {
      print("** Installing JTAF:\n");
      if ($args eq 'run')
      {
        print("** Installing and running JTAF\n");
        $args = "-t " . $ip[0] . " -v " . $dir_version . " -f pp470.txt -i";

      }
      else
      {
        $args = "-t " . $ip[0] . " -v " . $dir_version . " -i";
        print("** To run regression use the following command\n");
        print("   ./kickoff_tests.sh -t " . $ip[0] . " -v " . $dir_version . " -f pp470.txt  -l cap2 -r\n");
      }
    }
   elsif ($script eq 'install_tocs_jtaf.sh')
    {
      print("** Installing TOCS JTAF\n");
      if ($args eq 'run')
		{
        print("** Installing and running JTAF\n");
        $args = "-c all -i -f ".$regression_file;

      }
      else
      {
        $args = "-c all -i -f test_suites/init.txt";
        print("** To run regression use the following command\n");
        print("   ./kickoff_tests.sh -r -f TXTFILE.txt\n");
      }
    }
    # Login and execute the script.
    $cmd = "cd $destination; ./$script $args";

    my $output = zlogin( $zonename, $user, $cmd, 0 );
#print("'$script' Post install script output : '$output'");
    if ( $output != 0 ) {
        print( "** Couldn't run postinstall script '$script' in '$destination' as user '$user'\n" );
        return ( 1 );
    }
    else {
        return ( 0 );
    }
}
