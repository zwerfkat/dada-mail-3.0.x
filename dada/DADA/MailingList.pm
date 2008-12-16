package DADA::MailingList;

use lib qw(./ ../ ../DADA ../perllib);

use Carp qw(croak carp);

use DADA::Config qw(!:DEFAULT); 

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(Create Remove);

use strict;
use vars qw(@EXPORT);

sub Create {

    my ($args) = @_;

    if ( !$args->{list} ) {
        croak("You must supply a list name in the 'list' paramater.");
    }

    require DADA::App::Guts;
    if(     DADA::App::Guts::check_if_list_exists(-List => $args->{list}) == 1){ 
        croak 'The list, ' . $args->{list} . ' already exists! '; 
    }
    
    
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new(
				{
        			-list     => $args->{list},
        			-new_list => 1,	
				}
    		);

	unless($ls->isa('DADA::MailingList::Settings')){ 
		croak 'DADA::MailingList::Settings did not give back the right kind of object!'; 
	}
	
    DADA::App::Guts::make_all_list_files( -List => $args->{list} );

    $ls->save($args); 
    
	# This is sort of a hack, so that the available_lists() thingy is up to date: 
	# 
    DADA::App::Guts::available_lists(-clear_cache => 1);
    # This is a total hack, but I totally short-sighted this: 
    
    foreach(DADA::App::Guts::available_lists()){ 
                next if $_ eq $args->{list}; 
                my $l_ls = DADA::MailingList::Settings->new({-list => $_}); 
                my $l_li = $l_ls->get; 
                $ls->save({fallback_field_values => $l_li->{fallback_field_values}}); 
                last; 
    }
    # / end total hack. I'll have to think of something better...
            
    return $ls;

}

sub Remove {

    my ($args) = @_;

    if ( !$args->{-name} ) {
        croak("You must supply a list name in the '-name' paramater.");
    }
    
    require DADA::App::Guts;


    
    if(DADA::App::Guts::check_if_list_exists(-List => $args->{-name}, -Dont_Die => 1) == 0){ 
        croak 'The list, ' . $args->{-name} . ' does not exists! '; 
    }

    my $list = $args->{-name};
    my $delete_backups
        = $args->{-delete_backups} ? $args->{-delete_backups} : 1;



    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});

    my $li = $ls->get;




	# We have to remove mailouts, now. 
	require DADA::Mail::MailOut; 
	my @mailouts  = DADA::Mail::MailOut::current_mailouts(
						{ 
							-list => $args->{-name},
						}
					);  
    foreach (@mailouts){
		my $mailout = DADA::Mail::MailOut->new({ -list => $list }); 
           $mailout->associate($_->{id}, $_->{type});
		   $mailout->clean_up; 
	}
	
    require DADA::MailingList::Archives;

    #$DADA::MailingList::Archives::dbi_obj = $dbi_handle;
    my $la = DADA::MailingList::Archives->new({-list => $list});
    require DADA::MailingList::Subscribers;



    my $lh = DADA::MailingList::Subscribers->new({-list => $list});



    if ( $delete_backups == 1 ) {
	
        $ls->removeAllBackups();
        $la->removeAllBackups(1);
    }


    #mostly for the SQL backends
	foreach(keys  %{$lh->allowed_list_types }){ 
    	$lh->remove_this_listtype(-Type => $_);
	}

    $la->delete_all_archive_entries();

    # Nor this...
    DADA::App::Guts::delete_list_info( -List => $list );

    # Nor this...
    DADA::App::Guts::delete_list_template({ -List => $list });
	
	DADA::App::Guts::available_lists(-clear_cache => 1);
	
    require DADA::Logging::Usage;
	
	my $remote_host = exists($ENV{REMOTE_HOST}) ? $ENV{REMOTE_HOST} : ''; 
	my $remote_addr = exists($ENV{REMOTE_ADDR}) ? $ENV{REMOTE_ADDR} : ''; 

    my $log = new DADA::Logging::Usage;
    $log->mj_log( 
        $list, 
        'List Removed',
        'remote_host: ' . $remote_host . 
        ', ip_address: ' . $remote_addr,
     )
        if $DADA::Config::LOG{list_lives};

    return 1;

}

=pod

=head1 NAME

DADA::MailingList - Creates and Removes Dada Mail Mailing Lists

=head1 VERSION

=head1 SYNOPSIS

 use DADA::MailingList; 
 
 my $list = 'foo'; 
 
 
 # Create!
  my $ls = DADA::MailingList::Create({ list => 'mylist' }); 
 
 # $ls is now a DADA::MailingList::Settings object.
 
 # Remove!
 DADA::MailingList::Remove({ -name => 'mylist' }); 

=head1 DESCRIPTION

This module basically either creates, or removes a list. 


=head1 SUBROUTINES

=head2 Create

 my $ls = DADA::MailingList::Create({ list => 'mylist' });

Creates all the necessary files for a Dada Mailing List; B<$list> is the 
list shortname of your mailing list - which itself should be no more than 16
characters and should only include letters/numbers.

It returns a B<DADA::MailingList::Settings> object.

=head2 Remove

 DADA::MailingList::Remove({ -name => 'mylist', -delete_backups => 1}); 

Removes a Mailing List. the B<-name> paramater is required. B<-delete_backups> 
is optional, but when set to 1, will remove any backups of the list settings, 
archives or schedules. 

=head1 AUTHOR

Justin Simoni - http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999-2008 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut

1;