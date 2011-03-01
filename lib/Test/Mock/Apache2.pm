package Test::Mock::Apache2;

use strict;
use warnings;

our $VERSION = '0.01';

use Test::MockObject;

# ABSTRACT: Mock mod_perl2 objects when running outside of Apache

=head1 SYNOPSIS

  use Test::Mock::Apache2;

  my $r = Apache2::RequestUtil->request();
  my $apr_req = APR::Request::Apache2->handle($r);

  ...

=head1 DESCRIPTION

Allows to work with C<Apache2::*> objects without a running modperl server.

The purpose of this class is to be able to run some minimal unit tests for
a code base that's hopelessly entangled with the Apache internals.

Current state is, to say the least, B<very incomplete>. Will be hopefully
expanded as the unit test suite grows.

=cut

our $AP2_REQ;
our $AP2_REQ_UTIL;
our $APR_REQ_AP2;
our $APR_THROW_EXCEPTION = 0xDEADBEEF;

{

    my $COOKIE_JAR = {};

    sub cookie_jar {
        my $self = shift;

        if (@_) {
            $COOKIE_JAR = shift;
        }

        return $COOKIE_JAR;
    }

}

sub import {

    #arn "Init mocked objects...\n";
    init_mocked_objects();

    my @modules_to_fake = qw(
        Apache2::Request
        Apache2::Cookie
        Apache2::SubRequest
        Apache2::URI
    );

    #arn "Faking modules...\n";
    Test::MockObject->fake_module($_) for @modules_to_fake;
}

=method ap2_request

Return a mock L<Apache2::RequestRec> B<empty> object.

=cut

sub ap2_request {
    my $r = Test::MockObject->new();
    $r->fake_module('Apache2::RequestRec',
        hostname => sub {},
    );
    bless $r, 'Apache2::RequestRec';
    return $r;
}

=method ap2_request_ap2

Return a mock L<APR::Request::Apache2> B<empty> object.

=cut

sub apr_request_ap2 {
    my $r = Test::MockObject->new();
    $r->fake_module('APR::Request::Apache2',
        jar => sub {
            # Some primitive exception logic is needed
            # to simulate the cookie-containing-comma bug
            my $jar = Test::Mock::Apache2->cookie_jar();
            if (! ref $jar and ($jar == $APR_THROW_EXCEPTION)) {
                my $apr_req_err = Test::MockObject->new();
                $apr_req_err->fake_module('APR::Request::Error');
                $apr_req_err->set_always(jar => \&cookie_jar);
                return $apr_req_err;
            }
            bless $jar, "APR::Request::Cookie::Table";
        },
        handle => \&apr_request_ap2,
    );
    $r->fake_new('APR::Request::Apache2');
    bless $r, 'APR::Request::Apache2';
    return $r;
}

=method ap2_requestutil

Mocks the Apache2::RequestUtil> module to fake the C<+GlobalRequest>
option, so you can execute code like:

  my $r = Apache2::RequestUtil->request();

and get back an L<Apache2::RequestRec> object.
Uses L</ap2_request>.

=cut

sub ap2_requestutil {
    my $ap2_ru = Test::MockObject->new();
    $ap2_ru->fake_module('Apache2::RequestUtil',
        request => \&ap2_request,
    );
}

=method init_mocked_objects

Creates the initial instances of the mocked objects
for the various C<Apache2::*> classes.

=cut

sub init_mocked_objects {

    $AP2_REQ = ap2_request();
    $APR_REQ_AP2 = apr_request_ap2();
    $AP2_REQ_UTIL = ap2_requestutil();

}

1;
