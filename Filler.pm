package Hash::Filler;

use strict;
use Carp;
use vars qw($VERSION $DEBUG);

# How to check for the existence of an element

use constant TRUE	=> 0;	# Test if the value is true
use constant DEFINED	=> 1;	# Use defined()
use constant EXISTS	=> 2;	# Use exists() (default)

$VERSION	= '1.10';
$DEBUG		= '0';


# Preloaded methods go here.

sub new {
    my $type = shift;
    my $class = ref($type) || $type || "Hash::Filler";

    my $self = {
	'rules' => {},
	'loop' => 1,		# Avoid loops by default
	'method' => EXISTS,	# Which method to use to check for
				# existence of a hash key
    };

    bless $self, $class;
}

sub _sort {			# This is to be used by the sort
				# built-in
    return 
	    $b->{'pref'} <=> $a->{'pref'} or
		@{$a->{'prereq'}} <=> @{$b->{'prereq'}} or
		    $a->{'used'} <=> $b->{'used'};
}

sub _print_rule {
    my $rule = shift;
    printf("  (rule %s, used %s, pref %s)\n",  
	   $rule,
	   $rule->{'used'}, 
	   $rule->{'pref'});
    my $pre = 0;
    foreach my $pr (sort @{$rule->{'prereq'}}) {
	printf("  +- %s\n", $pr);
	++$pre;
    }
    print "  ** No prereq\n" unless $pre;
}

sub _dump_r_tree {
    my $self = shift;
    foreach my $key (keys %{$self->{'rules'}}) {
	my $dumped = 0;
	print "Rules for key $key:\n";
	foreach my $rule (sort _sort @{$self->{'rules'}->{$key}}) {
	    ++$dumped;
	    _print_rule $rule;
	}
	print "  No rules.\n" unless $dumped;
    }
}

sub loop {
    $_[0]->{'loop'} = $_[1];
}

sub method {
    $_[0]->{'method'} = $_[1];
}

sub add {
    push @{$_[0]->{'rules'}->{$_[1]}}, {
	'key' => $_[1],
	'code' => $_[2],
	'prereq' => $_[3],
	'pref' => $_[4] ? $_[4] : 100,
	'used' => 0,
    };
    1;
}

sub fill {
    my $self = shift;
    my $href = shift;
    my $key = shift;

    croak "->fill() must be given a hash reference"
	unless ref($href) eq 'HASH';

				# Provide a quick exit if the hash
				# key is already defined or if
				# we have no rules to generate it.

    if ($self->{'method'} == DEFINED) {
	return 1 if defined $href->{$key};
    }
    elsif ($self->{'method'} == EXISTS) {
	return 1 if exists $href->{$key};
    }
    else {
	return 1 if $href->{$key};
    }

    return 0 unless $self->{'rules'}->{$key};

				# Look through the available rules
				# and try to find an execution plan
				# to fill the requested $key

  RULE:    
    foreach my $rule (sort _sort @{$self->{'rules'}->{$key}}) {

	next if $self->{'loop'} and
	    $rule->{'used'};

	$rule->{'used'} ++;	# Mark this rule as being used
				# to control infinite recursion

				# Insure that all prerequisites
				# are there before attempting to
				# call this method

	foreach my $pr (@{$rule->{'prereq'}}) {

	    if ($self->{'method'} == DEFINED) {
		next if defined $href->{$key};
	    }
	    elsif ($self->{'method'} == EXISTS) {
		next if exists $href->{$key};
	    }
	    else {
		next if $href->{$key};
	    }

	    if (not $self->fill($href, $pr)) {
		next RULE;	# A prerequisite could not be
				# satisfied automatically so this
				# rule cannot be applied
	    }
	}

	_print_rule $rule if $DEBUG;
	
	my $ret = $rule->{'code'}->($href, $key);

	$rule->{'used'} --;	# This rule has hopefully
				# completed

	return $ret
	    if $ret;
    }

    return 0;			# No rule matched or was succesful.
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

HashFiller - Programatically fill elements of a hash based in prerequisites

=head1 SYNOPSIS

  use Hash::Filler;

  my $hf = new Hash::Filler;

  $hf->add('key1', sub { my $hr = shift; ... }, ['key2', 'key3'], $pref);
  $hf->add('key1', sub { my $hr = shift; ... }, [], $pref);
  $hf->add('key2', sub { my $hr = shift; ... }, ['key1', 'key3'], $pref);
  $hf->add('key3', sub { my $hr = shift; ... }, ['key1', 'key2'], $pref);

  $hf->loop(0);			# Don't try to avoid infinite loops

				# Test if a key exists using defined()
  $hf->method($Hash::Filler::DEFINED);

  my %hash;

  $hf->fill(\%hash, 'key1');	# Calculate the value of $hash{key1}
  $hash{'key2'} = 'foo';	# Manually fill a hash position
  $hf->fill(\%hash, 'key2');	# Calculate the value of $hash{key2}

=head1 DESCRIPTION

C<Hash::Filler> provides an interface so that hash elements can be
calculated depending in the existence of other hash elements, using
user-supplied code references.

There are a few relevant methods, described below:

=over 4

=item C<-E<gt>add($key, $code, $r_prereq, $pref)>

Adds a new rule to the C<Hash::Filler> object. The rule will be used
to fill the hash bucket identified with key $key. To fill this bucket,
the code referenced by $code will be invoked, passing it a reference
to the hash being worked on and the key that is being filled. This
will only be called if all of the hash buckets whose keys are in the
list referenced by $r_prereq C<exist>.

If the user-supplied code returns a false value, failure is assumed.

An optional preference can be supplied. This is used to help the
internal rule selection choose the better rule.

Multiple rules for the same $key and the same $r_prereq can be
added. The module will attempt to use them both but the execution
order will be undefined unless you use $pref. The default $pref is
100.

=item C<-E<gt>method($val)>

Which method to use to decide if a given key is present in the
hash. The accepted values are:

=over 4

=item C<$Hash::Filler::EXISTS> (default)

    The existence of a hash element or key is calculated using a
    construct like C<exists($hash{$key})>.

=item C<$Hash::Filler::DEFINED>

    The existence of a hash element or key is calculated using a
    construct like C<defined($hash{$key})>.

=item C<$Hash::Filler::TRUE>

    The existence of a hash element or key is calculated using a
    construct like C<$hash{$key}>.

=back

This allow this module to be customized to the particular application
in which it is being used. Be advised that changing this might cause a
change in which and when the rules are invoked for a particular hash
so probably it should only be used before the first call to
C<-E<gt>fill>.

By defult, the module uses exists() to do this check.

=item C<-E<gt>loop($val)>

Controls if the module should try to avoid infinite loops. A true $val
means that it must try (the default). A false value means otherwise.

=item C<-E<gt>fill($r_hash, $key)>

Attempts to fill the bucket $key of the hash referenced by $r_hash
using the supplied rules.

This method will return a true value if there are rules that allow the
requested $key to be calculated (or the $key is in the hash)
and the user supplied code returned true.

To avoid infinite loops, the code will not invoke a rule twice unless
C<-E<gt>loop> is called with a true value. The rules will be used
starting with the ones with less prerequisites, as these are assumed
to be lighter. To use a different ordering, specify $pref. Higher
values of $pref are used first.

=back

=head1 CAVEATS

This code uses recursion to resolve rules. This allows it to figure
out the value for a given key with only an incomplete rule
specification. Be warned that this might be costly if used with large
sets of rules.

=head1 AUTHOR

Luis E. Munoz < lem@cantv.net>

=head1 SEE ALSO

perl(1).

=head1 WARRANTY

Absolutely none.

=cut
