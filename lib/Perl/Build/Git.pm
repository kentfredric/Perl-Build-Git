use strict;
use warnings;

package Perl::Build::Git;
BEGIN {
  $Perl::Build::Git::AUTHORITY = 'cpan:KENTNL';
}
{
  $Perl::Build::Git::VERSION = '0.1.0';
}

# ABSTRACT: Convenience extensions for Perl::Build for bulk git work

use Perl::Build 0.17;
use Perl::Build::Built;
use parent 'Perl::Build';
use Path::Tiny qw( path );
use Carp qw( croak );


sub perl_git_src_uri { 'git://perl5.git.perl.org/perl.git' }

sub _extract_config {
  my ( $class, $args ) = @_;

  croak('cache_root required') unless exists $args{cache_root};
  croak('git_root required')   unless exists $args{git_root};

  my $config = {
    cache_root => path( delete $args{cache_root} )->absolute,
    git_root   => path( delete $args{git_root} )->absolute,
    persistent => ( exists $args{persistent} ? !!delete $args{persistent} : undef ),
  };

  # Define <describe>
  {
    require Git::Wrapper;
    $config->{describe} = [ Git::Wrapper->new( $config->{git_root} )->describe ]->[0];
  }

  # Define <dst_dir> and <tmp_dir>
  if ( $config->{persistent} ) {
    $config->{dst_dir} = $config->{cache_root}->child( $config->{describe} )->absolute;
  } else {
    $config->{tmp_dir} = File::Temp->newdir(
      $config->{describe} . 'XXXX',
      DIR     => $config->{cache_root}->stringify,
      CLEANUP => 1,
    );
    $config->{dst_dir} = path( $config->{tmp_dir}->dirname )->absolute
  }

  # Define <success_file>
  $config->{success_file} => $config->{dst_dir}->child('.success');

  return ( $config, $args );
}

sub install_git {
  my ( $class, %args ) = @_;

  my ( $config, $user_args ) = $class->_extract_config( \%args );

  my $computed_args =  {
    src_dir => $config->{git_root}->stringify,
    dst_dir => $config->{dst_dir}->stringify;
  };

  if ( $config->{success_file}->is_file ) {
      # Existing success!, don't build.
      return Perl::Build::Built->new(
          installed_path => $computed_args->{dst_dir}->stringify
      );
  }

  my $build = $class->install( %{$computed_args}, %{$user_args} );

  $config->{success_file}->touch;

  return $build;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Perl::Build::Git - Convenience extensions for Perl::Build for bulk git work

=head1 VERSION

version 0.1.0

=head1 SYNOPSIS

This is something that might be useful to call in a git bisect runner

    use Perl::Build::Git;
    my $install = Perl::Build::Git->install_git( 
            persistent => 1,
            cache_root => '/tmp/perls/',
            git_root   => '/path/to/git/checkout',
    );
    $install->run_env(sub{
            # Test Case Here
            exit 255 if $failed;
    });
    exit 0;

C<persistent = 1>  is intended to give each build its own unique directory, such as

    /tmp/perls/v5.17.10-44-g97927b0/

So that if you do multiple bisects, ( for the purpose of testing which incarnation of perl some module fails in ), testing against a perl that was previously tested against in a previous bisect should return a cached result, greatly speeding up the bisect ( at the expense of disk space ).

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
