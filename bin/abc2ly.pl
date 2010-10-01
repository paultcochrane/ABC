use v6;
use ABC::Header;
use ABC::Tune;
use ABC::Grammar;
use ABC::Actions;
use ABC::Duration;
use ABC::Note;

class Context {
    
}

sub HeaderToLilypond(ABC::Header $header) {
    say "\\header \{";
    
    my @titles = $header.get("T")>>.value;
    say "    title = \"{ @titles[0] }\"";
    
    say "}";
}

my %note-map = ( 'C' => "c'",
                 'D' => "d'",
                 'E' => "e'",
                 'F' => "f'",
                 'G' => "g'",
                 'A' => "a'",
                 'B' => "b'",
                 'c' => "c''",
                 'd' => "d''",
                 'e' => "e''",
                 'f' => "f''",
                 'g' => "g''",
                 'a' => "a''",
                 'b' => "b''"
   );

sub Duration(Context $context, $element) {
    $element.value ~~ ABC::Duration ?? $element.value.ticks !! 0;
}

my %cheat-length-map = ( '/' => "16",
                         "" => "8",
                         "1" => "8",
                         "2" => "4",
                         "3" => "4."
    );
   
sub StemToLilypond(Context $context, $stem) {
    if $stem ~~ ABC::Note {
        print " { %note-map{$stem.pitch} }{ %cheat-length-map{$stem.duration-to-str} } ";
    }
}
   
sub SectionToLilypond(Context $context, @elements) {
    say "\{";
    
    for @elements -> $element {
        given $element.key {
            when "stem" { StemToLilypond($context, $element.value); }
            when "barline" { say " |"; }
        }
    }
    
    say "\}";
}

sub BodyToLilypond(Context $context, @elements) {
    say "\{";

    my $start-of-section = 0;
    my $duration-in-section = 0;
    for @elements.keys -> $i {
        if $i > $start-of-section 
           && @elements[$i].key eq "barline" 
           && @elements[$i].value ne "|" {
            if $duration-in-section % 8 != 0 {
                print "\\partial 8*{ $duration-in-section % 8 } ";
            }
            
            if @elements[$i].value eq ':|:' | ':|' | '::' {
                print "\\repeat volta 2 "; # 2 is abitrarily chosen here!
            }
            SectionToLilypond($context, @elements[$start-of-section ..^ $i]);
            $start-of-section = $i + 1;
            $duration-in-section = 0;
        }
        $duration-in-section += Duration($context, @elements[$i]);
    }
    
    if $start-of-section + 1 < @elements.elems {
        if $duration-in-section % 8 != 0 {
            print "\\partial 8*{ $duration-in-section % 8 } ";
        }
        
        if @elements[*-1].value eq ':|:' | ':|' | '::' {
            print "\\repeat volta 2 "; # 2 is abitrarily chosen here!
        }
        SectionToLilypond($context, @elements[$start-of-section ..^ +@elements]);
    }

    say "\}";
}


my $match = ABC::Grammar.parse($*IN.slurp, :rule<tune_file>, :actions(ABC::Actions.new));

# just work with the first tune for now
my $tune = @( $match.ast )[0][0];

say '\\version "2.12.3"';
HeaderToLilypond($tune.header);
BodyToLilypond(Context.new, $tune.music);
