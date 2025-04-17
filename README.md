# An experiment in literate programming

I don't think anyone actually swears by literate programming. The only large project I'm aware of that uses it is that rendering book. Did Knuth himself use it a lot? I could imagine Tex or METAFONT being done in a literate style, but if they were, I haven't read the documents based on them.

Still, I don't want to knock it before I've tried it. The trouble is, when you look it up, you get a lot of commentary saying that "literate programming isn't just writing a lot of comments" -- pointing out that, in fact, the whole point is that you have these `weave` and `tangle` programs. The program and everything describing it (the literature?) coexist in the same document, and then you can run these two programs:

- `tangle` takes code chunks from the document and assembles them into a working (at least compile-able) program; and
- `weave` typesets the document into a beautiful thing with cross references and hyperlinks and an index and all of that.

So obviously I need a version of `tangle` at the very least in order to try out some literate programming. But then I decided: can I write `tangle` in a literate style? Obviously if my `tangle` does not exist, writing it in a literate way won't help. And, as I type this, my `tangle` does not exist. But I'm going to try to write it in a literate way anyway. Ideally, the process will be:

1. Write this document as if `tangle` existed;
2. Write the `tangle` program by hand (ideally following this spec); then
3. Use the handwritten version to generate the real version, thus bootstrapping my way into the joys of literate programming.

Now, I already suspect that steps 1 and 2 are not a linear process. That is, I'll write some stuff about the program, then write part of the program, and that will influence this document and vice-versa.

Let's get started.

## Scope

We only talked about tangle. I am ignoring the weave step. In Knuth's "Literate Programming" in *The Computer Journal*, `weave` has many features, mostly around cross-references, adding notes about where other chunks appear, and indexing everything. To me, those features seem made for printing out a document and flipping through. That seems unlikely these days. So I'm gonna skip all that.

The claim is this: the underlying document format is markdown. The `tangle` program will pull certain code blocks out of the markdown and assemble them into the program. The `weave` program is a no-op: I will simply convert the markdown to HTML (or even more simply, upload it to github and let them handle the rendering). Automatic hyperlinks and so on I am calling "nice to have."

## A program to tangle a program from a markdown document

I am trying to follow Knuth's paper, but the correspondence will not be completely exact, so instead, this document itself will specify how to write further documents in the same way.

The `tangle` program works by reading in a markdown file, extracting certain code blocks, and using some extra tagging information, assemble those blocks into a program.

The program only recognizes code blocks that use the three-backtick convention. Three backticks at the start of a line, then a special tag, some code, and the closing three backticks. Let's look at one:

```
«Program to tangle a program from a markdown document»
```

The first line of the block has to be some kind of tag. The tag name is indicated between «guillemets». I chose guillemets for a few reasons.

1. They're reminiscent of the notation of the original paper;
2. They're not too hard to type on my `en-US` macbook keyboard; and
3. I'm unlikely to use them in real code.

Note that by convention, the first tagged code block is a single tag with a high-level description of the program. This will be stored as the "root label" of the web when we do rendering.

Also, since we pull tagged blocks out of anywhere, we don't need to stick to the original paper's structure of commentary followed by code block.

### Assigning values to blocks; the top level

The high-level description ("title"?) block simply sets the root label. To associate code with it, we will use a slightly different tag form, again following Knuth's notation:

```perl
«Program to tangle»=
#!/usr/bin/perl -w
use strict;

«Choose input and output files»
«Declare globals and subroutines»
«Extract tagged code blocks from the input»
«Assemble tagged code blocks»
«Write completed program to the output»
```

Note the = operation on the first tag, where we are assigning the content of the rest of the block as the value of that tag. That is how we will assemble blocks. Also note that, as long as it's unambiguous, we should be able to shorten the label names in later rereferences.

Stream of consciousness note: I haven't actually opened another editor to write a single line of code yet. I wrote straight through from the top to this point. Also, I was considering putting, like a generic «front matter» block at the top of the program to include the shebang, and command line options maybe, and some global variables. In the Knuth paper, indeed, since it is Pascal, he explicitly calls out the sections where variables and constants need to be defined. I think, with perl, we can be more flexible, and I suddenly realized that things like argument parsing can fit in a high-level «Choose» block.

### Code block and tag format

So the important part is getting a tagged code block out of a chunk of text. Let's assume the format looks like this:

- a line with three backticks plus some optional info like programming language (if markdown supports syntax highlighting, say)
- a line that starts with «
- a label name
- a closing »
- an optional operation (so for we've only seen `=`, but `+=` will exist too, and maybe others)
- a newline
- an arbitrary chunk of text (code and other labels)
- a line with three backticks

So let's crack open `man perlre` and see how this can be done. (I also had to open my editor here because it took a lot of experimentation.) I learned that the `m` and `s` modifiers can be used together!

> Used together, as "/ms", they let the "." match any character whatsoever, while still allowing "^" and "$" to match, respectively, just after and just before newlines within the string.

```perl
«Regex to extract tagged code blocks»=
qr/^```(\N*)\n
    «
    (\N+?)
    »
    (\+?=)?
    \n
    (.*?)
    ^```\n
/msx
```

### Code block extraction

And now we can start writing the extraction part, assuming the file contents live in a variable named `$contents`.

```perl
«Extract tagged code blocks from the input»=
my $pattern = «Regex to extract tagged code blocks»;
while ($contents =~ m/$pattern/g) {
    my (undef, $label, $op, $code) = ($1, $2, $3, $4);
    «Strip whitespace from label»
    if (not defined $op) {
        «Set root label»
    } elsif ($op eq "=") {
        «Initialize label contents»
    } elsif ($op eq "+=") {
        «Append to label contents»
    }
}
```

Setting the root is easy enough, though I now notice we are going to need someplace to set up global variables such as `$root`. Also, we need a mapping of labels to contents, so let's start that too.

```perl
«Set root label»=
if (defined $root) {
    die "saw multiple root labels! (first was $root)";
} else {
    $root = $label;
    $blocks{$root} = "";
}
```

And now initialization -- remember how we wanted to be able to match shorter labels, as long as things were unambiguous? Let's assume we already know how to do that. We'll use it for the append step as well.

```perl
«Initialize label contents»=
my $exists = «Match a label to a block key»
if ($exists) {
    die "tried to initialize $label twice" if $blocks{$exists};
    $blocks{$exists} = $code;
} else {
    $blocks{$label} = $code;
}
```

Append:

```perl
«Append to label contents»=
my $exists = «Match a label to a block key»
if ($exists) {
    $blocks{$exists} .= $code;
} else {
    # maybe just magically initialize?
    die "tried to append to $label before initialization";
}
```

#### Some string utilities

As I'm staring at the «Match» labels used above, I keep wanting to replace them with a function call. That seems pretty normal, I guess. If you have an operation that you're using in the same way at different points in the program, the function is probably the correct unit of abstraction. This raises a question for me: should we have them be labeled blocks anyway, or should the function calls be inlined there completely? For now, not to break the flow, we can use a block. Though I note that the block only works because the variable names are the same in both cases.

And all of a suddent I realize why Knuth allows macros in his original paper! Anyway, for now let's add one more layer of blocks, though it kind of seems like a waste.

```perl
«Match a label to a block key»=
get_label_from_short_form($label);
```

And now I'm wondering how the interaction between literate programming and structured programming is supposed to work. They are both ways of assigning useful names to chunks of code. I guess literate programming has some flexibility in that things don't have to go in the computer's declaration order. And the things don't have to be "complete pieces of code" so to speak. However, it definitely looks like there is still space for using functions as the names of chunks of code when indeed they are functions.

And finally of course we need to strip leading and trailing whitespace. We might have been able to do this in the big extraction regex, but it was already looking sort of complicated. Again, could this be a function? This block depends on knowing that I care about the variable name `$label`.

```perl
«Strip whitespace from label»=
    $label =~ s/^\s*//;
    $label =~ s/\s*$//;
```

### Turning blocks into a program

So hopefully this should be pretty straightforward. We will start with the definition of the root block. Then, we iteratively replace «labels» within the code until there are none left. Then we're done!

```perl
«Assemble tagged code blocks»=
my $prog = $blocks{$root};
while ($prog =~ /«
                 (.*?)
                 »/x) {
    my $label = $1;
    «Strip whitespace»
    my $exists = «Match a label to a block key»
    if ($exists) {
        $prog =~ s/«
                   .*?
                   »/$blocks{$exists}/x;
    } else {
        die "unknown block $label!";
    }
}
```

At this point I am going to fire up an editor again and sort of entangle by hand, turning this description into a program I can try to run. I expect to run into errors.

**So** indeed I discovered several errors while typing things in by hand. It sort of goes to show that you don't get much of a feedback loop as you're writing this document, but instead need to run the partial programs and verify that they are working as anticipated. I could debug things since I was working in straight perl in a separate file, but it's not easy to backport those bugs into the document. Some things that happened:

1. I assumed I never use guillemets in code, but of course this document was using them, so now I had to go back and use the an extended regex `/x` to get them off of the same line.
2. I assumed an empty capture group would be an empty string but it is actually undef.
3. There were a few places in assignment where I mixed up `$label` and `$exists`.
4. And, of course I had to write the implementation of the function `get_label_from_short_form` and declare some global variables, which we did not yet do in this document.

Speaking of point 4, we should finish up this document's implementation.

### Input and output

```
«Choose input and output files»=
    «Set input from argv»
    «Set output from argv»
```

Let's decide that the first command line argument, if it exists, will be the input file, and the second, if it exists, will be the output file. 

```perl
«Set input from argv»=
my $inp = *STDIN;
if ($ARGV[0]) {
    open $inp, "<", $ARGV[0] or die "$!";
}
```

```perl
«Set output from argv»=
my $out = *STDOUT;
if ($ARGV[1]) {
    open $out, ">", $ARGV[1] or die "$!";
}
```

And now (the first use of append) we want to read the whole input file into the variable `$contents` as we described earlier. Normally, this is the point where would talk about processing the file line by line so that there is no limit on the size of the file to be processed. But, above, we already made the assumption that the whole file will be in memory. That's probably not a real limitation for a human-written markdown file on a modern machine.

```perl
«Choose input and output files»+=
$/ = undef;  # slurp
my $contents = <$inp>;
```

That takes care of input. We've already opened the output file, so if our assembly of the blocks worked, all we need to do is write the completely substituted program to the output file.

```perl
«Write completed program to the output»=
print $out $prog;
```

### Globals and subroutines

I am declaring some global variables last and the helper subroutine `get_label_from_short_form`. We've sort of been spoiled throughout the document that these need to exist. We need their block label at the top level. But at least we can defer them to the very end of program construction.

Let's write the function first, and relegate the globals to the very last thing.

```perl
«Get label from short form»=
sub get_label_from_short_form {
    my $label = shift;
    my @matches = grep { index($_, $label) == 0 } keys %blocks;
    return scalar @matches == 1 ? $matches[0] : "";
}
```

And then, in a last bit of tangling,

```perl
«Declare globals and subroutines»=
my $root = undef;
my %blocks;

«Get label from short form»
```

And at this point, after tangling, we finally get a `syntax OK` from `perl -cw`. But will it work? I will use the handwritten tangler to create a new perl script from this document, then run that script against its same source document and see if we get the same output.

**And** not quite, because for some reason the perl escapes `\N{U+00AB}` etc, which I have embedded here, do not seem to work when actually run as a perl script. I haven't investigated it enough, but instead I put back the literal guillements in the output, so it is pretty close:

**Edit**: As mentioned above, since labels have to be on the same line, updating the code to us an extended regular expression fixed this problem.

```
$ perl bootstrap.pl Tangle.md tangle.pl
$ perl tangle.pl Tangle.md | diff - tangle.pl
$
```

```
$ # This was a previous version of the document's output
$ perl bootstrap.pl Tangle.md tangle.pl
[ ... replace those unicode escapes with literals ... ]
$ perl tangle.pl Tangle.md tangle2.pl
$ diff tangle.pl tangle2.pl
27c27
< my $pattern = qr/^```\n«(\N+?)»(\+?=)?\n(.*?)^```\n/ms
---
> my $pattern = qr/^```\n\N{U+00AB}(\N+?)\N{U+00BB}(\+?=)?\n(.*?)^```\n/ms
66c66
< while ($prog =~ /«(.*?)»/) {
---
> while ($prog =~ /\N{U+00AB}(.*?)\N+{U+00BB}/) {
74c74
<         $prog =~ s/«.*?»/$blocks{$exists}/;
---
>         $prog =~ s/\N{U+00AB}.*?\N{U+00BB}/$blocks{$exists}/;
```

It's like an almost-quine!

## Conclusion

This was a fun experiment for a Saturday morning. Trying to write a program and a document describing the program at the same time was quite a challenge. Obviously the resulting 80-line perl script is not nearly as featureful as something Knuth would write, but it was enough to let me experiment.

It seems that while literate programming gives you a fair amount of leeway in how to introduce concepts to the reader, you're not completely free of the compiler's requirements. The end result of entanglement does need to end up in the right order. I was a bit disappointed that I couldn't find a way to "hide" the need for global variables from the reader until the end. Instead (and maybe this is better or more expected in Pascal or in pre-89 C) we have to leave a placeholder ahead of time for global and early declarations.

Another point of friction was picking out the dividing line between a named chunk of code as a literate chunk, and a named chunk of code that is just a function. Obviously pieces of reusable code should be in functions. Perhaps one idea is to put each function definition or declaration in its own literate chunk, but at the callsites, use the literal function name directly instead of trying to interpolate its little chunk. In this program's case, that would mean skipping the definition of «Match a label to a block key» and instead just calling `get_label_from_short_form` directly. We'd still keep the definition separate.

The other thing I haven't looked at is revision. I wrote this document straight through at the same time as I was writing the program. I wonder what the process of revision will be like. How do you plan the organization of a literate program? Are there best practices for how to introduce pieces of a program to the reader?

It took about three hours to write this document and the bootstrap perl script. That's more time than it would normally take me to bash something out. The resulting script is terribly formatted, too. Worse than by hand. But does the existence of this document outweight that?

In any event, having that script frees me to try other literate programming experiments in the future. Maybe I'll even improve it later. (I'd have to revise this document at the same time! That sounds daunting.)
