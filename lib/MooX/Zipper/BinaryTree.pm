package MooX::Zipper::BinaryTree;
use Moo;
extends 'MooX::Zipper';

# we store min/max bounds of subtree for benefit of -> find later
has lt => (
    is => 'ro',
    predicate => 'has_lt',
);

has gt => (
    is => 'ro',
    predicate => 'has_gt',
);

sub left {
    my $self = shift;
    $self->go('left')->but(
        defined $self->gt ? (gt => $self->gt) : (),
        lt => $self->focus->key
    );
}

sub right {
    my $self = shift;
    $self->go('right')->but(
        gt => $self->focus->key,
        defined $self->lt ? (lt => $self->lt) : (),
    );
}

sub first { $_[0]->top->leftmost }
sub last { $_[0]->top->rightmost }

sub leftmost {
    my $self = shift;
    my $zip = $self;
    while ($zip->focus->has_left) {
        $zip = $zip->left;
    }
    return $zip;
}

sub rightmost {
    my $self = shift;
    my $zip = $self;
    while ($zip->focus->has_right) {
        $zip = $zip->right;
    }
    return $zip;
}

sub next {
    my $self = shift;
    return $self->right->leftmost if $self->focus->has_right;
    return $self->up if $self->dir eq 'left';
    # the complex case, where we have a right parent.
    
    my $zip = $self->up;

    while ($zip->dir eq 'right') {
        $zip = $zip->up;
        return unless $zip->parent; # e.g. we are back at top
    }

    return $zip->up; # on a left path;
}

sub prev {
    my $self = shift;
    return $self->left->rightmost if $self->focus->has_left;
    return $self->up if $self->dir eq 'right';
    # the complex case, where we have a left parent.
    
    my $zip = $self->up;

    while ($zip->dir eq 'left') {
        $zip = $zip->up;
        return unless $zip->has_parent; # e.g. we are back at top
    }

    return $zip->up; # on a right path;
}

sub find {
    my ($self, $find) = @_;

    # Typically cmp routines are written in terms of $a/$b (which is a bit inconvenient
    # with packages) or @_[0..1]  So instead of doing a method call, we get this ref with
    # ->can, and subsequently call it as a *subroutine* ref, rather than a method.

    my $cmp = $self->focus->can('cmp') || sub { $_[0] cmp $_[1] };

    # we've stored the min/max bound of this sub-tree as we descend.  So we know
    # if we need to go back up the tree to search
    return $self->up->find($find) if ($self->has_lt and $cmp->($self->lt, $find) <= 0);
    return $self->up->find($find) if ($self->has_gt and $cmp->($self->gt, $find) >= 0);

    # otherwise, let's test to see if we're already at the element
    my $cmpd = $cmp->($self->focus->key, $find) or return $self;

    # otherwise we can search down left or right subtree as appopriate
    if ($cmpd > 0 and $self->focus->has_left) {
        return $self->left->find($find);
    }
    if ($cmpd < 0 and $self->focus->has_right) {
        return $self->right->find($find);
    }

    # element was not found
    return undef;
}

1;
