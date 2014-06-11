=head1 NAME

MooX::Zippable - helpers for writing immutable code

=head1 SYNOPSIS

    package Foo;
    use Moo;
    with 'MooX::Zippable';

    has foo   => ( isa => 'ro' );
    has child => ( isa => 'ro' );

and later...

    my $foo = Foo->new( foo => 1 );
    my $bar = $foo->but( foo => 2 );

    say $foo->foo; # still 1
    say $bar->foo; # 2

Support for updating linked objects

    my $foo = Foo->new(
        foo => 1,
        child => Foo->new( foo => 1 )
    );

    my $bar = $foo->traverse
        ->go('child')
        ->set(foo => 2)
        ->focus;

    say $foo->child->foo; # still 1
    say $bar->child->foo; # 2

Alternative syntax:

    my $bar = $foo->doTraverse( sub { $_
        ->go('child')
        ->set(foo => 2)
        });

=head1 WARNING

This module is designed to help you write immutable code, but Perl is designed
to give you as much rope as you need to hang yourself.

If you have two objects that are the same:

    my $a = $b;

Or even two objects that share child references:

    my $a = $b->traverse->go('left')->set(foo=>1)->focus;

And then I<mutate> a value in C<$a>:

    $a->{right}{bar} = 3;

Then you may have also overridden the value in C<$b>.  Some possible solutions to this
problem are:

    * don't do that.  only use Zippable's methods to safely return copied data.
    * check out various CPAN modules such as Readonly to lock down your data
      structures to keep you honest.
    * clone critical objects (or sub-trees) where there is a risk of data being
      mutated.

=head1 METHODS

=head2 C<but( $attribute =E<gt> $value, ... )>

Returns a copy of the object, but with the specified attributes overridden.

By default we provide the implemenation in L<MooX::But> which is a I<very
simple> shallow hash copy. See the docs for caveats and alternatives.  You are
welcome to override this!

=head2 traverse

Returns a L<MooX::Zipper> focused on this object.  You can use the zipper to
descend into child objects and modify them.

If we were using standard Moo with read-write accessors, we might update
an object like this:

    $employee->company->address->telephone( '01234 567 890' );

Because we are using immutable objects we can't simply call:

    $employee->company->address->but(telephone => '01234 567 890' );

All that will do will return a copy of the address object, with the new
telephone number.  e.g.

    say $employee->company->address->telephone; # has not been updated!

To update it, you'd have to update every intermediate object in turn:

    my $employee2 = $employee->but(
        company => $employee->company->but(
            address => $employee->company->address->but(
                telephone => '01234 567 890' )));

Yuck!  Instead, we can call traverse and descend the tree, and set the new field.
The zipper will take care of updating all the intermediate references.

    my $employee2 = $employee->traverse
        ->go('company')
        ->go('address')
        ->set( telephone => '01234 567 890' )
        ->focus;

=head2 doTraverse

You might dislike having to remember to write C<-E<gt>focus> at the end of
every traversal chain.  Instead, you can use C<doTraverse> which takes a
coderef, that gets passed the root zipper as C<$_> and its first arg.  With
this we can rewrite the previous expression as:

    my $employee2 = $employee->doTraverse( sub { $_
        ->go('company')
        ->go('address')
        ->set( telephone => '01234 567 890' )
        });

=head1 SEE ALSO

=over 4

=item *

The zipper methods in L<MooX::Zipper>

=item *

L<MooseX::Attribute::ChainedClone>

=item *

L<Data::Zipper>

=item *

Zippers in Haskell. L<http://learnyouahaskell.com/zippers> for example.

=back

=cut

package MooX::Zippable;
use Moo::Role;
with 'MooX::But';
require MooX::Zipper;
use Attribute::Memoize;


sub zip {
    my ($self, @roles) = @_;
    return $self->zipper(
        zipper_class => __PACKAGE__->get_zipper_class(@roles)
    );
}

sub zipper {
    my ($self, %args) = @_;

    return ($args{zipper_class} || 'MooX::Zipper')
        ->new( focus => $self, %args );
}

sub get_zipper_class :Memoize {
    my ($class, @roles) = @_;
    return 'MooX::Zipper' unless @roles;
    return $class->create_class_with_roles('MooX::Zipper', @roles);
}

sub doZipper {
    my ($self, $code) = @_;
    for ($self->zipper) {
        my $zipper = $code->($_);
        my $value = $zipper->unzip;
        return $value;
    }
}

=head1 CONTRIBUTIONS

haarg pointed out caveats with the implementation of C<but> and proposed L<MooX::CloneWith>

dysfun provided valuable feedback and suggested the native zipper types.

=head1 AUTHOR and LICENCE

(C) 2014 osfameron@cpan.org

Licensed under the same terms as Perl itself.

=cut

1;
