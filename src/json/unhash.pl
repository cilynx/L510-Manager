#!/usr/bin/perl -w

#use strict;
use JSON;

my $json_file = "parameters.json";

my $json_text = do {
  open(my $json_fh, $json_file);
  local $/;
  <$json_fh>
};

my $json = JSON->new->allow_nonref->canonical;
my $data = $json->decode($json_text);

foreach my $group(keys(%$data)) {
   foreach my $parameter(keys(%{$data->{$group}})) {
      my @array = ();
      foreach my $option(keys(%{$data->{$group}->{$parameter}->{'options'}})) {
	 push(@array, $data->{$group}->{$parameter}->{'options'}->{$option});
      }
      $data->{$group}->{$parameter}->{'options'} = \@array;
   }
}

#print $json->pretty->encode($data);

open my $json_fh, ">", $json_file;
print $json_fh $json->pretty->encode($data);
close $json_fh;
