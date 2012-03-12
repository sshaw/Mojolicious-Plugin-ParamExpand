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

  $app->helper(named => sub {
      my ($c, $field, $object) = @_;
      croak 'field name required' unless $field;

      return ($field, $c->param($field)) if defined $c->param($field);

      my $sep  = $class->separator;
      my @path = split /\Q$sep/, $field;

      if(!$object) {
          $object = $c->stash($path[0]);
          _invalid_parameter($field, "nothing in the stash for '$path[0]'") unless $object;
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
        *{"${class}::$_"} = sub { $val } if defined $val;
    }
}

1;

__END__

=pod

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
      $order->{items}->[0]->{price};
      # ...
  }

  # In your view
  %= text_field named('order.address')
  %= hidden_field named('order.items.0.id')


=head1 DESCRIPTION

L<Mojolicious::Plugin::ParamExpand> turns request parameters into nested data 
structures using L<CGI::Expand> and helps you use these values in a form.

=head1 MOJOLICIOUS VERSION

Due to the old way C<Mojolicious::Controller> handled multi-valued request parameters 
versions of Mojolicious B<less than> 2.52 will not work with this plugin. If this is a problem for
you try L<Mojolicious::Plugin::GroupedParams>.

=head1 OPTIONS

Options must be specified when loading the plugin.

=head2 separator

  $self->plugin('ParamExpand', separator => ',')

The character used to separate the data structure's hierarchy in the 
flattened parameter. Defaults to C<'.'>.

=head2 max_array

  $self->plugin('ParamExpand', max_array => 10)

Maximum number of array elements C<CGI::Expand> will create. 
Defaults to C<100>.

To force the array into a hash keyed by its indexes set this to C<0>.

=head1 Methods

=head2 param

This is just L<Mojolicious::Controller/param>. Using C<Mojolicious::Plugin::ParamExpand> a
request with the parameters 

  users.0.name=nameA&users.1.name=nameB&id=123

will return a nested data structure for the param C<'users'>

  @users = $self->param('users');   
  $users[0]->{name};    	
  $users[1]->{name};   	

Other parameters can be accessed as usual

  $id = $self->param('id');

The flattened parameter name can also be used

  $name0 = $self->param('users.0.name');   

=head3 Arguments

C<$name>

The name of the parameter.

=head3 Returns

The value for the given parameter. If applicable it will be an expanded 
data structure. 

Top level arrays will be returned as arrays B<not> as array references. 
This is how C<Mojolicious> behaves. In other words

  users.0=userA&users.1=userB 

is equivlent to 

  users=userA&users=userB

If this is undesirable you could L<< set C<max_array> to zero|/max_array >>.

=head2 named

Helps to create form fields suitable for parameter expansion. 
Use this with the L<various Mojolicious tag helpers|Mojolicious::Plugin::TagHelpers>.

  <%= text_field named('users.0.name') %>
  <%= text_field named('users.1.name') %>

If the expanded representation of the parameter exists in 
L<the stash|Mojolicious::Controller/stash> it will be used as the default. 
If a value for the flattened representation exists (e.g., from a form submission) 
it will be used instead. 

You can also supply the object or reference to retrieve the value from

  <%= text_field named('book.upc', $item) %>

=head3 Arguments

C<$name>

The name of the parameter.

C<$object> 

Optional. The object to retrieve the default value from. Must be a reference to a 
hash, an array, or something blessed. If not given the value will be retrieved from
the stash or, for previously submitted forms, the request parameter C<$name>.

=head3 Returns

A two element list containing the unexpanded parameter name and value. 

=head3 Errors

An error will be raised if:

=over 4

=item * C<$name> is not provided

=item * C<$name> cannot be retrieved from C<$object>. 

=item * C<$object> cannot be found in the stash and no default was given

=back
 
=head1 SEE ALSO

L<CGI::Expand>, L<Mojolicious::Plugin::GroupedParams>
