#!/usr/bin/perl
use common::sense;

# Look for libraries also in the same directory as the script lives
use FindBin;
use lib $FindBin::Bin;

use AddrStoreBuild;

# Don't start parallel instances of the script
single_instance '/tmp/build-fwup-sets.lock';

my $blacklist = blacklist_load;

my $dbh = db_connect;

# Sequential version numbers. Half a minute resolution should be enough to
# never generate two same versions when the script is run from cron (therefore
# not more often than once a minute). On the other hand, there should be
# huge reserve before the number overflows.
my $version = (time / 30) % (2**31);

# Should we update the config version?
my $bump_config_version;

sub fake_set_generate($$$) {
	my ($setname, $family, $mode) = @_;

	# What addresses do we want in the set?
	my $required = $dbh->selectall_arrayref('SELECT remote FROM fake_blacklist WHERE FAMILY(remote) = ? AND mode = ?', undef, $family, $mode);
	my %required = map { $_->[0] => 1 } @$required;

	# What addresses are there?
	my ($max_epoch, $content) = addr_store_content('fwup_addresses', 'set', $setname);

	# TODO: We want to keep addresses that drop out of the fake_blacklist but are still active.
	# We need to look into the firewall logs for the activity of such address to decide that.

	# Decide what to add and what to remove.
	my %to_delete = %$content;
	delete @to_delete{keys %required};
	my %to_add = %required;
	delete @to_add{keys %$content};
	my $mod = $dbh->prepare("INSERT INTO fwup_addresses (set, epoch, version, add, address) VALUES (?, ?, ?, ?, ?)");
	$mod->execute($setname, $max_epoch, $version, 1, $_) for keys %to_add;
	$mod->execute($setname, $max_epoch, $version, 0, $_) for keys %to_delete;

	# How many elements are needed in the set?
	my $needed = keys %required;
	if ($dbh->selectrow_array('SELECT 1 FROM fwup_sets WHERE name = ? AND maxsize < ?', undef, $setname, $needed)) {
		# The set is too small. We need to increase the size somehow. Provide some reserve (round it up to nearest power of two)
		my $size = 2;
		$size *= 2 while $size < $needed;
		$dbh->do('UPDATE fwup_sets SET maxsize = ?, hashsize = ? WHERE name = ?', undef, $size, 4 * $size, $setname);
		$bump_config_version = 1;
	}
}

fake_set_generate 'turris_100FA4E0_lb_a_4', 4, 'hard';
fake_set_generate 'turris_100FA4E0_lb_a_6', 6, 'hard';

$dbh->do("UPDATE config SET value = ? WHERE plugin = 'fwup' AND name = 'version'", undef, $version) if $bump_config_version;

$dbh->commit;