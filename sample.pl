use Hash::Filler;

my $hf = new Hash::Filler;

$Hash::Filler::DEBUG = 1;

$hf->add(
	 'key0', 
	 sub { $_[0]->{$_[1]} = 'i:key0'; sleep 1;},
    []);

$hf->add(
    'key2', 
    sub { $_[0]->{$_[1]} = 'i:key2'; }, 
    []);

$hf->add(
    'key1', 
    sub { $_[0]->{$_[1]} = 'k1(' . $_[0]->{'key0'} . ')'; sleep 1;}, 
    ['key0']);

$hf->add(
    'key2', 
    sub { $_[0]->{$_[1]} = 'k2(' . $_[0]->{'key1'} . ')'; }, 
    ['key1'], 1000);

$hf->add(
    'key3', 
    sub { $_[0]->{$_[1]} = 'k3(' . $_[0]->{'key4'} . ')'; }, 
    ['key4'], 1000);

$hf->add(
    'key4', 
    sub { $_[0]->{$_[1]} = 'k4(' . $_[0]->{'key3'} . ')'; sleep 1;}, 
    ['key3'], 1000);

$hf->add(
    'key4', 
    sub { $_[0]->{$_[1]} = 'i:key4'; }, 
    []);

$hf->add(
    'key5', 
    sub { 1; }, 
    []);

$hf->add(
    'key6', 
    sub { $_[0]->{$_[1]} = ' does ' . 
	      ((exists $_[0]->{'key5'}) ? '' : ' not ') . ' exist'; 1; }, 
    ['key5']);

$hf->method($Hash::Filler::TRUE);

$hf->dump_r_tree;

my %hash;

foreach my $key (qw(key7 key2 key3 key6 key6))
{
    print "*** Filling of key $key:\n";
    if ($hf->fill(\%hash, $key)) {
	print "*** Succeeded\n";
    }
    else {
	print "*** Failed\n";
    }
    print "*** Value of $key is ", $hash{$key}, "\n";
}

$hf->dump_r_tree;
