#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2016-2019 -- leonerd@leonerd.org.uk

package Syntax::Keyword::Try;

use strict;
use warnings;

our $VERSION = '0.11';

use Carp;

require XSLoader;
XSLoader::load( __PACKAGE__, $VERSION );

=head1 NAME

C<Syntax::Keyword::Try> - a C<try/catch/finally> syntax for perl

=head1 SYNOPSIS

 use Syntax::Keyword::Try;

 sub foo
 {
    try {
       attempt_a_thing();
       return "success";
    }
    catch {
       warn "It failed - $@";
       return "failure";
    }
 }

=head1 DESCRIPTION

This module provides a syntax plugin that implements exception-handling
semantics in a form familiar to users of other languages, being built on a
block labeled with the C<try> keyword, followed by at least one of a C<catch>
or C<finally> block.

As well as providing a handy syntax for this useful behaviour, this module
also serves to contain a number of code examples for how to implement parser
plugins and manipulate optrees to provide new syntax and behaviours for perl
code.

=cut

=head1 KEYWORDS

=head2 try

   try {
      STATEMENTS...
   }
   ...

A C<try> statement provides the main body of code that will be invoked, and
must be followed by either a C<catch> statement, a C<finally> statement, or
both.

Execution of the C<try> statement itself begins from the block given to the
statement and continues until either it throws an exception, or completes
successfully by reaching the end of the block. What will happen next depends
on the presence of a C<catch> or C<finally> statement immediately following
it.

The body of a C<try {}> block may contain a C<return> expression. If executed,
such an expression will cause the entire containing function to return with
the value provided. This is different from a plain C<eval {}> block, in which
circumstance only the C<eval> itself would return, not the entire function.

The body of a C<try {}> block may contain loop control expressions (C<redo>,
C<next>, C<last>) which will have their usual effect on any loops that the
C<try {}> block is contained by.

The parsing rules for the set of statements (the C<try> block and its
associated C<catch> and C<finally>) are such that they are parsed as a self-
contained statement. Because of this, there is no need to end with a
terminating semicolon.

Note (especially to users of L<Try::Tiny> and similar) that the C<try {}>
block itself does not necessarily stop exceptions thrown inside it from
propagating outside. It is the presence of a later C<catch {}> block which
causes this to happen. A C<try> with only a C<finally> and no C<catch> will
still propagate exceptions up to callers as normal.

=head2 catch

   ...
   catch {
      STATEMENTS...
   }

A C<catch> statement provides a block of code to the preceding C<try>
statement that will be invoked in the case that the main block of code throws
an exception. The C<catch> block can inspect the raised exception by looking
in C<$@> in the usual way.

Presence of this C<catch> statement causes any exception thrown by the
preceding C<try> block to be non-fatal to the surrounding code. If the
C<catch> block wishes to optionally handle some exceptions but not others, it
can re-raise it (or another exception) by calling C<die> in the usual manner.

As with C<try>, the body of a C<catch {}> block may also contain a C<return>
expression, which as before, has its usual meaning, causing the entire
containing function to return with the given value. The body may also contain
loop control expressions (C<redo>, C<next> or C<last>) which also have their
usual effect.

If a C<catch> statement is not given, then any exceptions raised by the C<try>
block are raised to the caller in the usual way.

=head2 finally

   ...
   finally {
      STATEMENTS...
   }

A C<finally> statement provides a block of code to the preceding C<try>
statement (or C<try/catch> pair) which is executed afterwards, both in the
case of a normal execution or a thrown exception. This code block may be used
to provide whatever clean-up operations might be required by preceding code.

Because it is executed during a stack cleanup operation, a C<finally {}> block
may not cause the containing function to return, or to alter the return value
of it. It also cannot see the containing function's C<@_> arguments array
(though as it is block scoped within the function, it will continue to share
any normal lexical variables declared up until that point). It is protected
from disturbing the value of C<$@>. If the C<finally {}> block code throws an
exception, this will be printed as a warning and discarded, leaving C<$@>
containing the original exception, if one existed.

=head1 VALUE SEMANTICS

=over 4

B<Warning:> the feature described in this section is experimental. This
experiment may be stablised in a later version, or may be altered or removed
without further notice. It is present here for testing and evaluation
purposes.

Additionally, on I<perl> versions 5.18 and later, it will produce a warning
in the C<experimental> category.

=back

The syntax provided by this module may be used as a value-yielding expression.
Because this syntax is new, experimental, and somewhat surprising, it must be
specifically requested by name C<try_value>:

   use Syntax::Keyword::Try qw( try try_value );

   my $result = try do { ... } catch { ... };

Also, on Perl versions 5.24 and later:

   my $result = try do { ... } finally { ... };

   my $result = try do { ... } catch { ... } finally { ... };

Specifically, note that the expression must be spelled as C<try do { ... }> so
that the syntax is distinct from that used by control-flow statements. The
interposed C<do> keyword reminds the reader, and instructs the syntax parser,
that this will be an expression, not a statement. It is not necessary to
similarly notate the C<catch> or C<finally> blocks.

In this case, the syntax behaves syntactically like an expression, and may
appear anywhere a normal expression is allowed. It follows similar semantics
to the purely control-flow case; if the code in the C<try> block does not
throw an exception, then the expression as a whole yields whatever value the
C<try> expression did. If it fails, then the C<catch> block is executed and
the expression yields its resulting value instead. A C<finally> block, if
present, will be evaluated for side-effects before the rest of the expression
returns.

Remember that, as in the control-flow case, the C<return> keyword will cause
the entire containing function to return, not just the C<try> block.

=cut

=head1 OTHER MODULES

There are already quite a number of modules on CPAN that provide a
C<try/catch>-like syntax for Perl.

=over 2

=item *

L<Try>

=item *

L<TryCatch>

=item *

L<Try::Tiny>

=item *

L<Syntax::Feature::Try>

=back

They are compared here, by feature:

=head2 True syntax plugin

Like L<Try> and L<Syntax::Feature::Try>, this module is implemented as a true
syntax plugin, allowing it to provide new parsing rules not available to
simple functions. Most notably here it means that the resulting combination
does not need to end in a semicolon.

In comparison, L<Try::Tiny> is plain perl and provides its functionality using
regular perl functions; as such its syntax requires the trailing semicolon.

L<TryCatch> is a hybrid that uses L<Devel::Declare> to parse the syntax tree.

=head2 C<@_> in a try or catch block

Because the C<try> and C<catch> block code is contained in a true block rather
than an entire anonymous subroutine, invoking it does not interfere with the
C<@_> arguments array. Code inside these blocks can interact with the
containing function's array as before.

This feature is unique among these modules; none of the others listed have
this ability.

=head2 C<return> in a try or catch block

Like L<TryCatch> and L<Syntax::Feature::Try>, the C<return> statement has its
usual effect within a subroutine containing syntax provided by this module.
Namely, it causes the containing C<sub> itself to return.

In comparison, using L<Try> or L<Try::Tiny> mean that a C<return> statement
will only exit from the C<try> block.

=head2 C<next>/C<last>/C<redo> in a try or catch block

The loop control keywords of C<next>, C<last> and C<redo> have their usual
effect on dynamically contained loops.

L<Syntax::Feature::Try> documents that these do not work there. The other
modules make no statement either way.

=head2 Value Semantics

Like L<Try> and L<Syntax::Feature::Try>, the syntax provided by this module
only works as a syntax-level statement and not an expression when the
experimental C<try_value> feature described above has not been enabled. You
cannot assign from the result of a C<try> block. Additionally,
final-expression value semantics do not work, so it cannot be contained by a
C<do> block to yield this value.

In comparison, the behaviour implemented by L<Try::Tiny> can be used as a
valued expression, such as assigned to a variable or returned to the caller of
its containing function. Such ability is provided by this module if the
experimental C<try_value> feature is enabled, though it must be spelled
differently as C<try do { ... }>.

=head2 C<try> without C<catch>

Like L<Syntax::Feature::Try>, the syntax provided by this module allows a
C<try> block to be followed by only a C<finally> block, with no C<catch>. In
this case, exceptions thrown by code contained by the C<try> are not
suppressed, instead they propagate as normal to callers. This matches the
behaviour familiar to Java or C++ programmers.

In comparison, the code provided by L<Try> and L<Try::Tiny> always suppress
exception propagation even without an actual C<catch> block.

The L<TryCatch> module does not allow a C<try> block not followed by C<catch>.

=head2 Typed C<catch>

Like L<Try> and L<Try::Tiny>, this module makes no attempt to perform any kind
of typed dispatch to distinguish kinds of exception caught by C<catch> blocks.

L<TryCatch> and L<Syntax::Feature::Try> both attempt to provide a kind of
typed dispatch where different classes of exception are caught by different
blocks of code, or propagated up entirely to callers.

The author considers the lack of such ability in this module to be a feature.
That kind of dispatch on type matching of a controlling expression is too
useful a behaviour to be constrained to exception catching. If the language is
to provide such a facility, it should be more universally applicable as a
stand-alone independent ability.

=cut

sub import
{
   my $class = shift;
   my $caller = caller;

   $class->import_into( $caller, @_ );
}

sub import_into
{
   my $class = shift;
   my ( $caller, @syms ) = @_;

   @syms or @syms = qw( try );

   my %syms = map { $_ => 1 } @syms;
   $^H{"Syntax::Keyword::Try/try"}++ if delete $syms{try};
   $^H{"Syntax::Keyword::Try/try_value"}++ if delete $syms{try_value};

   # Ignore requests for these, as they come automatically with `try`
   delete @syms{qw( catch finally )};

   croak "Unrecognised import symbols @{[ keys %syms ]}" if keys %syms;
}

=head1 WITH OTHER MODULES

=head2 Future::AsyncAwait

As of C<Future::AsyncAwait> version 0.10 and L<Syntax::Keyword::Try> version
0.07, cross-module integration tests assert that basic C<try/catch> blocks
inside an C<async sub> work correctly, including those that attempt to
C<return> from inside C<try>.

   use Future::AsyncAwait;
   use Syntax::Keyword::Try;

   async sub attempt
   {
      try {
         await func();
         return "success";
      }
      catch {
         return "failed";
      }
   }

=head1 KNOWN BUGS

=head2 Thread-safety at load time cannot be assured before perl 5.16

On F<perl> versions 5.16 and above this module is thread-safe.

On F<perl> version 5.14 this module is thread-safe provided that it is
C<use>d before any additional threads are created.

However, when using 5.14 there is a race condition if this module is loaded
late in the program startup, after additional threads have been created. This
leads to the potential for it to be started up multiple times concurrently,
which creates data races when modifying internal structures and likely leads
to a segmentation fault, either during load or soon after when more code is
compiled.

As a workaround, for any such program that creates multiple threads, loads
additional code (such as dynamically-discovered plugins), and has to run on
5.14, it should make sure to

   use Syntax::Keyword::Try;

early on in startup, before it spins out any additional threads.

(See also L<https://rt.cpan.org/Public/Bug/Display.html?id=123547>)

=head2 $@ is not local'ised by C<try do> before perl 5.24

On F<perl> versions 5.24 and above, or when using only control-flow statement
syntax, C<$@> is always correctly C<local>ised.

However, when using the experimental value-yielding expression version
C<try do {...}> on perl versions 5.22 or older, the C<local>isation of C<$@>
does not correctly apply around the expression. After such an expression, the
value of C<$@> will leak out if a failure happened and the C<catch> block was
invoked, overwriting any previous value that was visible there.

(See also L<https://rt.cpan.org/Public/Bug/Display.html?id=124366>)

=head1 ACKNOWLEDGEMENTS

With thanks to C<Zefram>, C<ilmari> and others from C<irc.perl.org/#p5p> for
assisting with trickier bits of XS logic.

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
