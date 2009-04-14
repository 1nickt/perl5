#!./perl

BEGIN {
    chdir 't';
    @INC = '../lib';
    require './test.pl';
}
use strict;

use Tie::Array;
use Tie::Hash;

# Predeclare vars used in the tests:
my $deep1 = []; push @$deep1, \$deep1;
my $deep2 = []; push @$deep2, \$deep2;

my @nums = (1..10);
tie my @tied_nums, 'Tie::StdArray';
@tied_nums =  (1..10);

my %hash = (foo => 17, bar => 23);
tie my %tied_hash, 'Tie::StdHash';
%tied_hash = %hash;

{
    package Test::Object::NoOverload;
    sub new { bless { key => 1 } }
}

{
    package Test::Object::CopyOverload;
    sub new { bless { key => 1 } }
    use overload '~~' => sub { my %hash = %{ $_[0] }; %hash ~~ $_[1] };
}

our $ov_obj = Test::Object::CopyOverload->new;
our $obj = Test::Object::NoOverload->new;

my @keyandmore = qw(key and more);
my @fooormore = qw(foo or more);
my %keyandmore = map { $_ => 0 } @keyandmore;
my %fooormore = map { $_ => 0 } @fooormore;

# Load and run the tests
plan "no_plan";

while (<DATA>) {
    next if /^#/ || !/\S/;
    chomp;
    my ($yn, $left, $right, $note) = split /\t+/;

    local $::TODO = $note =~ /TODO/;
    match_test($yn, $left, $right);
    match_test($yn, $right, $left);
}

sub match_test {
    my ($yn, $left, $right) = @_;

    die "Bad test spec: ($yn, $left, $right)"
	unless $yn eq "" || $yn eq "!" || $yn eq '@';

    my $tstr = "$left ~~ $right";

    my $res = eval $tstr;

    chomp $@;

    if ( $yn eq '@' ) {
	ok( $@ ne '', "$tstr dies" )
	    and print "# \$\@ was: $@\n";
    } else {
	my $test_name = $tstr . ($yn eq '!' ? " does not match" : " matches");
	if ( $@ ne '' ) {
	    fail($test_name);
	    print "# \$\@ was: $@\n";
	} else {
	    ok( ($yn eq '!' xor $res), $test_name );
	}
    }
}



sub foo {}
sub bar {42}
sub gorch {42}
sub fatal {die "fatal sub\n"}

sub a_const() {die "const\n" if @_; "a constant"}
sub b_const() {die "const\n" if @_; "a constant"}
sub FALSE() { 0 }
sub TRUE() { 1 }
sub TWO() { 1 }

# Prefix character :
#   - expected to match
# ! - expected to not match
# @ - expected to be a compilation failure
# Data types to test :
#   Object-overloaded
#   Object
#   Code
#   Code()
#   Coderef
#   Hash
#   Hashref
#   Array
#   Arrayref
#   Regex (// and qr//)
#   Num
#   Str
#   undef
__DATA__
# OBJECT
# - overloaded
	$ov_obj		"key"
!	$ov_obj		"foo"
	$ov_obj		{"key" => 1}
	$ov_obj		{"key" => 1, bar => 2}		TODO
!	$ov_obj		{"foo" => 1}
	$ov_obj		["key" => 1]
!	$ov_obj		["foo" => 1]
	$ov_obj		@keyandmore
!	$ov_obj		@fooormore
	$ov_obj		%keyandmore			TODO
!	$ov_obj		%fooormore
	$ov_obj		/key/
!	$ov_obj		/foo/
	$ov_obj		qr/Key/i
!	$ov_obj		qr/foo/
	$ov_obj		sub { shift ~~ "key" }
!	$ov_obj		sub { shift eq "key" }
!	$ov_obj		sub { shift ~~ "foo" }
!	$ov_obj		\&foo
	$ov_obj		\&bar
@	$ov_obj		\&fatal
!	$ov_obj		FALSE
!	$ov_obj		\&FALSE
!	$ov_obj		undef
	$ov_obj		$ov_obj

# regular object
@	$obj	"key"
@	$obj	{"key" => 1}
@	$obj	["key" => 1]
@	$obj	/key/
@	$obj	qr/key/
@	$obj	sub { 1 }
@	$obj	sub { 0 }
@	$obj	\&foo
@	$obj	\&fatal
@	$obj	FALSE
@	$obj	\&FALSE
!	$obj	undef
@	$obj	$obj

# CODE ref against argument
#  - arg is code ref
	\&foo		\&foo
!	\&foo		sub {}
!	\&foo		sub { "$_[0]" =~ /^CODE/ }
!	\&foo		\&bar
	\&fatal		\&fatal
!	\&foo		\&fatal

# - arg is not code ref
	1	sub{shift}
!	0	sub{shift}
!	undef	sub{shift}
	undef	sub{not shift}
	FALSE	sub{not shift}
	1	sub{scalar @_}
	[]	\&bar
	{}	\&bar
	qr//	\&bar
!	[]	\&foo
!	{}	\&foo
!	qr//	\&foo
!	undef	\&foo
	undef	\&bar
@	undef	\&fatal
@	1	\&fatal
@	[]	\&fatal
@	"foo"	\&fatal
@	qr//	\&fatal
# pass argument by reference
	@fooormore	sub{scalar @_ == 1}
	@fooormore	sub{"@_" =~ /ARRAY/}
	%fooormore	sub{"@_" =~ /HASH/}
	/fooormore/	sub{ref $_[0] eq 'Regexp'}

# - null-prototyped subs
	a_const		"a constant"
	a_const		a_const
	a_const		b_const
	\&a_const	\&a_const
!	\&a_const	\&b_const
!	undef		\&FALSE
	undef		\&TRUE
!	0		\&FALSE
	0		\&TRUE
!	1		\&FALSE
	1		\&TRUE
	\&FALSE		\&FALSE
!	\&FALSE		\&foo
!	\&FALSE		\&bar
!	\&TRUE		\&foo
!	\&TRUE		\&bar
!	\&TWO		\&foo
!	\&TWO		\&bar
	\&FALSE		\&FALSE

# - non-null-prototyped subs
!	\&bar		\&gorch
	bar		gorch
@	fatal		bar

# HASH ref against:
#   - another hash ref
	{}		{}
!	{}		{1 => 2}
	{1 => 2}	{1 => 2}
	{1 => 2}	{1 => 3}
!	{1 => 2}	{2 => 3}
	\%main::	{map {$_ => 'x'} keys %main::}

#  - tied hash ref
	\%hash		\%tied_hash
	\%tied_hash	\%tied_hash

#  - an array ref
	\%::		[keys %main::]
!	\%::		[]
	{"" => 1}	[undef]
	{ foo => 1 }	["foo"]
	{ foo => 1 }	["foo", "bar"]
	\%hash		["foo", "bar"]
	\%hash		["foo"]
!	\%hash		["quux"]
	\%hash		[qw(foo quux)]

#  - a regex
	{foo => 1}	qr/^(fo[ox])$/
!	+{0..99}	qr/[13579]$/

#  - a string
	+{foo => 1, bar => 2}	"foo"
!	+{foo => 1, bar => 2}	"baz"


# ARRAY ref against:
#  - another array ref
	[]			[]
!	[]			[1]
	[["foo"], ["bar"]]	[qr/o/, qr/a/]
	["foo", "bar"]		[qr/o/, qr/a/]
!	["foo", "bar"]		[qr/o/, "foo"]
	$deep1			$deep1
!	$deep1			$deep2

	\@nums			\@tied_nums

#  - a regex
	[qw(foo bar baz quux)]	qr/x/
!	[qw(foo bar baz quux)]	qr/y/

# - a number
	[qw(1foo 2bar)]		2
	[qw(foo 2)]		2
	[qw(foo 2)]		2.0_0e+0
!	[qw(1foo bar2)]		2

# - a string
!	[qw(1foo 2bar)]		"2"
	[qw(1foo 2bar)]		"2bar"

# Number against number
	2		2
!	2		3
	0		FALSE
	3-2		TRUE

# Number against string
	2		"2"
	2		"2.0"
!	2		"2bananas"
!	2_3		"2_3"
	FALSE		"0"

# Regex against string
	qr/x/		"x"
!	qr/y/		"x"

# Regex against number
	12345		qr/3/


# Test the implicit referencing
	@nums		7
	@nums		\@nums
!	@nums		\\@nums
	@nums		[1..10]
!	@nums		[0..9]

	%hash		"foo"
	%hash		/bar/
	%hash		[qw(bar)]
!	%hash		[qw(a b c)]
	%hash		%hash
	%hash		+{%hash}
	%hash		\%hash
	%hash		%tied_hash
	%tied_hash	%tied_hash
	%hash		{ foo => 5, bar => 10 }
!	%hash		{ foo => 5, bar => 10, quux => 15 }

	@nums		{  1, '',  2, '' }
	@nums		{  1, '', 12, '' }
!	@nums		{ 11, '', 12, '' }

# UNDEF
!	3		undef
!	1		undef
!	[]		undef
!	{}		undef
!	\%::main	undef
!	[1,2]		undef
!	%hash		undef
!	@nums		undef
!	"foo"		undef
!	""		undef
!	!1		undef
!	\&foo		undef
!	sub { }		undef
	undef		undef
	$::undef	undef
