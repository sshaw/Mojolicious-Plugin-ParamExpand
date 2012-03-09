package Mojolicious::Plugin::ParamExpand;

use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use Scalar::Util 'blessed';
use CGI::Expand;

our $VERSION = '0.01';

sub register
{
  my ($self, $app, $config) = @_;
  my $class = 'Mojolicious::Plugin::ParamExpand::expander';

  _make_package($class, $config);

  $app->hook(before_dispatch => sub {
      my $c = shift;
      my $hash = $class->expand_hash($c->req->params->to_hash);
      $c->param($_ => $hash->{$_}) for keys %$hash;
  });

  $app->helper(field => sub {
      my ($c, $field, $object) = @_;
      croak 'field name required' unless $field;

      my $sep  = $class->separator;
      # Trim field
      my @path = split /\Q$sep/, $field;

      if(!$object) {
          $object = $c->stash($path[0]);
          _invalid_parameter($field, "there is nothing in stash for '$path[0]'") unless $object;
      }

      # Remove the stash key for $object
      shift @path;

      while(defined(my $accessor = shift @path)) {
          my $isa = ref($object);

          if(blessed($object) && $object->can($accessor)) {
              $object = $object->$accessor;
          }
          elsif($isa eq 'HASH') {
              # If blessed and !can() do we _really_ want to look inside?
              $object = $object->{$accessor};
          }
          elsif($isa eq 'ARRAY') {
              _invalid_parameter($field, "non-numeric index '$accessor' used to access an ARRAY")
                  unless $accessor =~ /^\d+$/;
	      
              $object = $object->[$accessor];
          }
          else {
              my $type = $isa || 'type that is not a reference';
              _invalid_parameter($field, "cannot use '$accessor' to access a $type");
          }
      }

      ($field, $object);
  });
}

sub _invalid_parameter
{
    my ($field, $message) = @_;
    croak "Invalid parameter '$field': $message";
}

sub _make_package
{
    my ($class, $config) = @_;

    no strict 'refs';
    @{"${class}::ISA"} = 'CGI::Expand';

    for(qw|max_array separator|) {
        my $val = $config->{$_};
        *{"${class}::$_"} = sub { $val } if $val;
    }
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::ParamExpand - Use objects and data structures in your forms

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('ParamExpand', %options);
   
  # Mojolicious::Lite
  plugin 'ParamExpand', %options;

  # In your action
  sub action
  {
      my $self = shift;
      my $order = $self->param('order');
      $order->{address};
      $order->{items}->[0]->{id};
      $order->{items}->[1]->{price};
      # ...
  }

  # In your view
  %= text_field field('order.address')
  %= hidden_field field('order.items.0.id')


=head1 DESCRIPTION

L<Mojolicious::Plugin::ParamExpand> turns the request parameters into a nested data structure using L<CGI::Expand>.

=head1 OPTIONS

Options must be specified when loading the plugin.

=head2 C<separator>

  $self->plugin('ParamExpand', separator => ',')

The charactor used to separate the flattened structure. 

=head2 C<max_array>

  $self->plugin('ParamExpand', max_array => 10)

Maximum number of array elements C<CGI::Expand> will create. 

=head1 Methods

=head2 C<param>

Retrieve the nested data structure for the given parameter. 
Overrides L<Mojolicious::Controller/param>. 

For example, the following parameters 
C<users.0.name=nameA&users.1.name=nameB&id=123> will create:

  $users = $self->param('users');   
  $users->[0]->{name}    	
  $users->[1]->{name}    	

  $id = $self->param('id');

=head2 C<field>

Create form fields suitable for parameter expansion.

  <%= text_field field('users.0.name') %>
  <%= text_field field('users.1.name') %>

You can also supply the object or reference:

  <%= text_field field('book.upc', $item) %>
  
=head1 SEE ALSO

L<CGI::Expand>, L<Mojolicious::Plugin::GroupedParams>

=cut
