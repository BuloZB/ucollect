#!iusr/bin/perl
use common::sense;
use Digest::SHA;
use File::Path;
use Getopt::Long;

my (@plugins, %branches, $url, $pass_file, $default, $serie, $categories);

GetOptions
	'url=s' => \$url,
	'default=s' => \$default,
	'serie=s' => \$serie,
	'pass-fille=s' => \$pass_file,
	"branch=s%" => \%branches,
	'categories=s' => \$categories,
	"plugins=s" => \@plugins or die "Bad params";

sub parse($) {
	my ($hexes) = @_;
	return map hex, $hexes =~ /(.{2})/g;
}

# Read the compiled-in password
open my $pf, '<', $pass_file or die "Could not read password file $pass_file: $!\n";
my $passwd = <$pf>;
close $pf;
chomp $passwd;
$passwd =~ s/[,{}]//g;
$passwd =~ s/\s//g;
$passwd =~ s/0x//g;

my @passwd = parse $passwd;

open my $cfile, '<', $categories or die "Could not read category file '$categories': $!\n";
my %categories;
my $current;
while (<$cfile>) {
	chomp;
	s/\s*(|#.*)$//;
	next unless /\S/;
	if (/(\S+):/) {
		$current = $1;
	} elsif (/(\S+)/) {
		$categories{$1} = $current;
	}
}
close $cfile;

sub get_hash($) {
	my ($list) = @_;
# Get versions of packages
	open my $packages, '-|', 'wget', "$url/lists/$list", '-O', '-' or die "Couldn't download package list: $!\n";
	my @packages = <$packages>;
	close $packages or die "Error downloading package list: $!\n";

	my %packages = map {
		my ($name, $version) = split;
		$name => "$url/packages/$name-$version.ipk"
	} @packages;

	my %paths = map {
		my ($name, $version) = split;
		my $file = $name;
		$file =~ s/-/_/;
		$name => "usr/lib/libplugin_${file}_${version}.so"
	} @packages;

	for my $plugin (@plugins) {
		system 'wget', ($packages{$plugin} // next), '-O', 'package.ipk' and die "Couldn't download package $packages{$plugin}\n";
		system 'tar', 'xf', 'package.ipk' and die "Can't unpack package for $plugin\n";
		system 'tar', 'xf', 'data.tar.gz' and die "Can't unpack data for $plugin\n";
		my $library = $paths{$plugin};
		my $sha = Digest::SHA->new(256);
		$sha->addfile($library);
		my @digest = parse $sha->hexdigest;
		for my $i (0..@passwd - 1) {
			$passwd[$i] ^= $digest[$i];
		}
		rmtree 'usr';
	}

	return join '', map sprintf("%02X", $_), @passwd;
}
my $hash = get_hash $default;
my %hashes = map {
	$_ => get_hash $_
} keys %branches;
say "UPDATE clients SET builtin_passwd = '$hash' WHERE name like '$default%'";
say "UPDATE clients SET builtin_passwd = '$hashes{$branches{$_}}' WHERE name = '$_'" for grep { /^$serie/ } keys %hashes;
