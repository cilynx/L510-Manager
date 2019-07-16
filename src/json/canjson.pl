#!/usr/bin/perl -w

use strict;
use JSON;

my $json_file = "parameters.json";

my $json_text = do {
  open(my $json_fh, $json_file);
  local $/;
  <$json_fh>
};

my $json = JSON->new->allow_nonref->canonical;
my $data = $json->decode($json_text);

open my $json_fh, ">", $json_file;
print $json_fh $json->pretty->encode($data);
close $json_fh;
