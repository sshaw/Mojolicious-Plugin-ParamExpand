use Mojo::Base -strict;
use Mojolicious::Lite;
use Test::More tests => 49;
use Test::Mojo;

package Model;

sub new  {  my $class = shift; bless { @_ }, $class }
sub id   { shift->{id} }
sub name { shift->{name} }

1;

package main;

sub qs { join '&', @_ }
sub user { Model->new(id => 1, name => 'sshaw') }

sub selector 
{ 
    my $val = shift;
    my $fx  = pop;
    my $sep = shift || '.';
    $fx->($sep, $val);
}

sub select_id 
{ 
    selector(@_, sub { 
	sprintf 'input[name="user%sid"][value="%s"]', shift, shift 
    }); 
}

sub select_name 
{ 
    selector(@_, sub { 
	sprintf 'input[name="user%sname"][value="%s"]', shift, shift
    });
}

{

plugin 'ParamExpand';

get '/params_are_expanded' => sub {
    my $self   = shift;
    my $hash   = $self->param('hash');
    my @array  = $self->param('array');
    my $scalar = $self->param('scalar');
    
    $self->render(hash   => $hash, 
		  array  => \@array, 
		  scalar => $scalar);
};

get '/flattened_params_still_exist';

get '/named_with_no_object_argument' => sub {
    my $self = shift;
    $self->render('form', user => user());
};

get '/named_with_hash_argument' => sub {
    my $self = shift;
    my $user = { id => 2, name => 'coelhinha' };
    $self->render('form', user => $user);
};

get '/named_with_array_argument' => sub {
    my $self = shift;
    my @users = ({ name => "sshaw" }, { name => 'coelhinha' });
    $self->render('form_for_array_with_hash', users => \@users);
};

# Given a param of "user.X", $object should be used in the form, not $user 
get '/named_with_object_argument' => sub {
    my $self = shift;
    my $object = Model->new(id => 2, name => 'xxx');
    $self->render('form_with_object_argument', user => user(), object => $object);
};

# Same as above, except with a hash
get '/named_with_hash_as_object_argument' => sub {
    my $self = shift;
    my $object = { id => 2, name => 'xxx' };
    $self->render('form_with_object_argument', user => user(), object => $object);
};

# Error cases
get '/named_with_missing_param_name' => sub { shift->named };
get '/named_with_invalid_param_name' => sub { shift->named('bad_name') };
get '/named_array_with_non_numeric_index' => sub { shift->named('array.x', []) };
get '/named_with_a_non_reference'=> sub { shift->named('x.y', 123) };
get '/named_with_a_non_existant_accessor' => sub { shift->named('user.x', Model->new) };


my $qs = qs 'hash.a=a',
    	    'hash.b.c=b',
    	    'array.0=0',
            'array.1=1',
            'scalar=scalar';

my $t = Test::Mojo->new;
$t->get_ok("/params_are_expanded?$qs")
    ->status_is(200)
    ->content_like(qr/\Qa,b|0,1|scalar/);

$t->get_ok("/flattened_params_still_exist?$qs")
    ->status_is(200)
    ->content_like(qr/\Qa,b|0,1|scalar/);

$t->get_ok('/named_with_no_object_argument')
    ->status_is(200)
    ->element_exists(select_id(1))
    ->element_exists(select_name('sshaw'));

# Here, $qs should be used over the Model
$qs = qs 'user.id=x', 'user.name=skye';
$t->get_ok("/named_with_no_object_argument?$qs")
    ->status_is(200)
    ->element_exists(select_id('x')) 
    ->element_exists(select_name('skye')); 

$t->get_ok("/named_with_hash_argument")
    ->status_is(200)
    ->element_exists(select_id(2))
    ->element_exists(select_name('coelhinha'));
   
$t->get_ok("/named_with_array_argument")
    ->status_is(200)
    ->element_exists('input[name="users.0.name"][value="sshaw"]')
    ->element_exists('input[name="users.1.name"][value="coelhinha"]');

$t->get_ok('/named_with_object_argument')
    ->status_is(200)
    ->element_exists(select_id(2)) 
    ->element_exists(select_name('xxx')); 
    
$t->get_ok('/named_with_hash_as_object_argument')
    ->status_is(200)
    ->element_exists(select_id(2)) 
    ->element_exists(select_name('xxx')); 

$t->get_ok('/named_with_missing_param_name')
    ->status_is(500)
    ->content_like(qr/name required/);

$t->get_ok('/named_with_invalid_param_name')
    ->status_is(500)
    ->content_like(qr/nothing in the stash/);

$t->get_ok('/named_array_with_non_numeric_index')
    ->status_is(500)
    ->content_like(qr/non-numeric index/);

$t->get_ok('/named_with_a_non_reference')
    ->status_is(500)
    ->content_like(qr/not a reference/);

$t->get_ok('/named_with_a_non_existant_accessor')
    ->status_is(500)
    ->content_like(qr/access a Model/);

}

{
    plugin 'ParamExpand', separator => '->';
    get '/user_defined_separator' => sub {
	my $self = shift;
	my $user = $self->param('user');
	$self->render('alt_form', user => $user);
    };

    my $qs = qs 'user->id=x', 'user->name=skye';
    my $t = Test::Mojo->new;
    $t->get_ok("/user_defined_separator?$qs")
	->status_is(200)
	->element_exists(select_id('x', '->')) 
	->element_exists(select_name('skye', '->')); 
}

# {
#     plugin 'ParamExpand', max_array => 1;

#     get '/user_defined_max_array' => sub { 
# 	shift->render(text => 'success!') 
#     };

#     my $qs = qs 'users.0=a', 'users.1=b';
#     my $t = Test::Mojo->new;    
#     $t->get_ok("/user_defined_max_array?$qs")
# 	->status_is(500)
# 	->content_like(qr/limit exceeded/);
# }
      
__DATA__
@@ form.html.ep
<%= text_field named('user.name') %>
<%= hidden_field named('user.id') %>

@@ alt_form.html.ep
<%= text_field named('user->name') %>
<%= hidden_field named('user->id') %>

@@ form_for_array_with_hash.html.ep
<%= text_field named('users.0.name') %>
<%= text_field named('users.1.name') %>

@@ form_with_object_argument.html.ep
<%= text_field named('user.name', $object) %>
<%= hidden_field named('user.id', $object) %>

@@ params_are_expanded.html.ep
<%= $hash->{a} %>,<%= $hash->{b}->{c} %>|<%= $array->[0] %>,<%= $array->[1] %>|<%= $scalar %>

@@ flattened_params_still_exist.html.ep
<%= param('hash.a') %>,<%= param('hash.b.c') %>|<%= param('array.0') %>,<%= param('array.1') %>|<%= param('scalar') %>

@@ exception.html.ep
<%= stash('exception')->message %>
