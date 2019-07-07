#!/usr/bin/perl -w

use strict;
use JSON;

my $json_file = "parameters.json";
my $dat = shift;

my $params;

open(my $fh, '<', $dat) or die "Cannot open $dat: $!";
while(my $line = <$fh>) {
   if($line =~ /^#/) {
      if($line =~ /^#([0-9][0-9])-XX : (\V*)/) {
         $params->{$1}->{'name'} = $2;
      }
   } else {
      if($line =~ /^([0-9][0-9])-([0-9][0-9]) (.*)@(.*)\$/) {
         $params->{$1}->{$2}->{'name'} = $3;
         if($4 ne '----') {
            $params->{$1}->{$2}->{'default'} = $4;
         }
      }
   }
}
close $fh;

foreach my $group_number (keys %$params) {
   my $group = $params->{$group_number};
   foreach my $parameter_number (keys %$group) {
      my $parameter = $group->{$parameter_number};
      if($parameter_number ne "name") {
         if($parameter->{"name"} =~ s/\(Hz\)//) {
            $parameter->{"unit"} = "Hz";
         }
         if($parameter->{"name"} =~ s/\(Sec\)//) {
            $parameter->{"unit"} = "Seconds";
         }
         if($parameter->{"name"} =~ s/\(S\)//) {
            $parameter->{"unit"} = "Seconds";
         }
         if($parameter->{"name"} =~ s/\(Vac\)//) {
            $parameter->{"unit"} = "AC Volts";
         }
         if($parameter->{"name"} =~ s/\(%\)//) {
            $parameter->{"unit"} = "%";
         }
         if($parameter->{"name"} =~ s/\(A\)//) {
            $parameter->{"unit"} = "Amps";
         }
         if($parameter->{"name"} =~ s/\(Vdc\)//) {
            $parameter->{"unit"} = "DC Volts";
         }
         if($parameter->{"name"} =~ s/\(V\)//) {
            $parameter->{"unit"} = "Volts";
         }
         if($parameter->{"name"} =~ s/\(degree C\)//) {
            $parameter->{"unit"} = "C";
         }
         if($parameter->{"name"} =~ s/\(KHz\)//) {
            $parameter->{"unit"} = "kHz";
         }
         if($parameter->{"name"} =~ s/\(kW\)//) {
            $parameter->{"unit"} = "kW";
         }
         if($parameter->{"name"} =~ s/\(RPM\)//) {
            $parameter->{"unit"} = "RPM";
         }
         if($parameter->{"name"} =~ s/\(Rpm\)//) {
            $parameter->{"unit"} = "RPM";
         }
         if($parameter->{"name"} =~ s/\(day\)//) {
            $parameter->{"unit"} = "Day";
         }
         if($parameter->{"name"} =~ s/\(hour\)//) {
            $parameter->{"unit"} = "Hour";
         }

      }
   }
}

my $json = JSON->new->allow_nonref->canonical;

open $fh, ">", $json_file;
print $fh $json->pretty->encode($params);
close $fh;
