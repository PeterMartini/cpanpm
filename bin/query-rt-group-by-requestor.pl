use strict;
use warnings;

use RT::Client::REST;
use Getopt::Long;
use List::Util qw(max);
use YAML::Syck;

my %Config = (
              server      => 'http://rt.cpan.org',
              username    => 'ANDK',
              password    => '',
              chunksize   => 396,
             );

GetOptions(\my %config, map { "$_=s" } keys %Config);
while (my($k,$v) = each %config) {
  $Config{$k} = $v;
}

my $yaml_db_file = __FILE__;
$yaml_db_file =~ s/\.pl$/.yml/;
my $ALL;
if (-e $yaml_db_file) {
  $ALL = YAML::Syck::LoadFile($yaml_db_file);
} else {
  $ALL = {};
}
my $curmax = max keys %{$ALL->{tickets} || {}};
$curmax ||= 1;
FINDHOLES: for (my $i = 1; $i <= $curmax; $i++) {
  if (exists $ALL->{tickets}{$i}) {
  } else {
    $curmax = $i;
    last FINDHOLES;
  }
}

my $nextmax = $curmax + $Config{chunksize};

my $rt = RT::Client::REST->new(
                               server  => $Config{server},
                               timeout => 300
                              );

if ($Config{password}) {
  eval { $rt->login( username => $Config{username}, password => $Config{password} ); };
  die "problem logging in: '$@'" if $@;

  my @ids;
  eval {
    @ids = $rt->search(
                       type    => 'ticket',
                       query   => qq[
            (Id >= $curmax and Id <= $nextmax)
        ],
                      );
  };
  die "search failed: $@" if $@;

  my %ids;
  @ids{@ids} = ();
  $|=1;
  print "filling $curmax..$nextmax\n";
 ID: for my $id ($curmax..$nextmax) {
    if ($ALL->{tickets}{$id}){
    } else {
      my $feedback;
      if (exists $ids{$id}) {
        $feedback = ".";
      } elsif (keys %ids) {
        $feedback = "_";
      } else {
        print "stopping at $id. Maybe we have reached the upper end\n";
        last ID;
      }
      $ALL->{tickets}{$id} = exists $ids{$id} ? $rt->show(type => 'ticket', id => $id) : {};
      print $feedback;
    }
    delete $ids{$id};
    unless ($id % 15){
      print "z";
      sleep 3;
    }
  }
  YAML::Syck::DumpFile("$yaml_db_file.new", $ALL);
  rename "$yaml_db_file.new", $yaml_db_file;
  print "filled\n";
}

sub who {
  my($v) = @_;
  my $who = $v->{Requestors} || $v->{Creator};
  return "" unless $who;
  if ($who =~ s/\@cpan\.org(,.*)?$//) {
    $who = uc $who;
  }
  my %alias = (
               'ANDY@PETDANCE.COM, ESUMMERS' => 'PETDANCE',
               'Marek.Rouchal@gmx.net'      => 'MAREKR',
               'marek.rouchal@infineon.com' => 'MAREKR',
               'aaron@FreeBSD.org'          => 'ACDALTON',
               'alexchorny@gmail.com'       => 'CHORNY',
               'andreas.koenig@anima.de'    => 'ANDK',
               'andy@petdance.com'          => 'PETDANCE',
               'a.r.ferreira@gmail.com'     => 'FERREIRA',
               'ask@develooper.com'         => 'ABH',
               'at@altlinux.org'            => 'ATOURBIN',
               'at@altlinux.ru'             => 'ATOURBIN',
               'audreyt@audreyt.org'        => 'AUDREYT',
               'autrijus@autrijus.org'      => 'AUDREYT',
               'barbie@missbarbell.co.uk'   => 'BARBIE',
               'blair@orcaware.com'         => 'BZAJAC',
               'corion@corion.net'          => 'CORION',
               'cpan@ali.as'                => 'ADAMK',
               'cpan@audreyt.org'           => 'AUDREYT',
               'cpan@chrisdolan.net'        => 'CDOLAN',
               'cpan@clotho.com'            => 'CLOTHO',
               'david@landgren.net'         => 'DLAND',
               'dha@panix.com'              => 'DHA',
               'gbarr@pobox.com'            => 'GBARR',
               'imacat@mail.imacat.idv.tw'  => 'IMACAT',
               'ivorw-cpan@xemaps.com'      => 'IVORW',
               'jdhedden@1979.usna.com'     => 'JDHEDDEN',
               'jesse@bestpractical.com'    => 'JESSE',
               'jesse@fsck.com'             => 'JESSE',
               'jhi@iki.fi'                 => 'JHI',
               'mark@summersault.com'       => 'MARKSTOS',
               'mark@twoshortplanks.com'    => 'MARKF',
               'merlyn@stonehenge.com'      => 'MERLYN',
               'mnodine@alum.mit.edu'       => 'NODINE',
               'nadim@khemir.net'           => 'NKH',
               'njh@bandsman.co.uk'         => 'NJH',
               'njh@ecs.soton.ac.uk'        => 'NJH',
               'nospam-abuse@bloodgate.com' => 'TELS',
               'ntyni@iki.fi'               => 'Niko Tyni',
               'nothingmuch@woobling.org'   => 'NUFFIN',
               'rafl@debian.org'            => 'FLORA',
               'rcaputo@pobox.com'          => 'RCAPUTO',
               'ron@savage.net.au'          => 'RSAVAGE',
               'rurban@x-ray.at'            => 'RURBAN',
               'shlomif@iglu.org.il'        => 'SHLOMIF',
               'schmorp@schmorp.de'         => 'MLEHMANN',
               'schwern@pobox.com'          => 'MSCHWERN',
               'schwern@bestpractical.com'  => 'MSCHWERN',
               'slaven@rezic.de'            => 'SREZIC',
               'slaven@cpan'                => 'SREZIC',
               'slaven.rezic@berlin.de'     => 'SREZIC',
               'steve.hay@uk.radan.com'     => 'SHAY',
               'steve@fisharerojo.org'      => 'SMPETERS',
               'steven@knowmad.com'         => 'WMCKEE',
               'william@knowmad.com'        => 'WMCKEE',
              );
  $who = $alias{$who} || $who;
}

keys %{$ALL->{tickets}}; # reset iterator
my %S;
TICKET: while (my($k,$v) = each %{$ALL->{tickets}}) {
  my $who = who($v);
  next TICKET unless $who;
  $S{$who}++;
}
my $top = 1;
for my $k (sort {$S{$b} <=> $S{$a}} keys %S) {
  printf "%2d: %34s %4d\n", $top, $k, $S{$k};
  last if $top >= 40;
  $top++;
}


__END__


The first top 40 produced by the script above @ 32007 (2007-12-30)
after many hours of data collecting:

 1:                              guest  486
 2:                             SREZIC  388
 3:                           MSCHWERN  383
 4:                               ANDK  347
 5:                              ADAMK  316
 6:                           MARKSTOS  304
 7:                             CHORNY  248
 8:                               RRWO  205
 9:                             WMCKEE  161
10:                           SMPETERS  136
11:                              TONYC  132
12:                           LGODDARD  129
13:                             CDOLAN  117
14:                           JDHEDDEN  114
15:                            RCAPUTO  110
16:                               RJBS  101
17:                             MAREKR  101
18:                             MTHURN   98
19:                           ATOURBIN   85
20:                           PETDANCE   84
21:                              SAPER   79
22:                             BARBIE   72
23:                              JESSE   71
24:                                NKH   62
25:                             IMACAT   60
26:                             CORION   60
27:                           ACDALTON   59
28:                           DAGOLDEN   58
29:                            RSAVAGE   57
30:                             MERLYN   52
31:                          HANENKAMP   51
32:                          Niko Tyni   50
33:                               TELS   49
34:                           LTHEGLER   47
35:                              MARKF   47
36:                          PODMASTER   47
37:                            JPIERCE   47
38:                            GROUSSE   46
39:                             BZAJAC   46
40:                               KANE   44