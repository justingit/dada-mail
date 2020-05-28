package File::Slurper;
$File::Slurper::VERSION = '0.012';
use strict;
use warnings;
 
use Carp 'croak';
use Exporter 5.57 'import';
 
use Encode 2.11 qw/FB_CROAK STOP_AT_PARTIAL/;
use PerlIO::encoding;
 
our @EXPORT_OK = qw/read_binary read_text read_lines write_binary write_text read_dir/;
 
sub read_binary {
        my $filename = shift;
 
        # This logic is a bit ugly, but gives a significant speed boost
        # because slurpy readline is not optimized for non-buffered usage
        open my $fh, '<:unix', $filename or croak "Couldn't open $filename: $!";
        if (my $size = -s $fh) {
                my $buf;
                my ($pos, $read) = 0;
                do {
                        defined($read = read $fh, ${$buf}, $size - $pos, $pos) or croak "Couldn't read $filename: $!";
                        $pos += $read;
                } while ($read && $pos < $size);
                return ${$buf};
        }
        else {
                return do { local $/; <$fh> };
        }
}
 
use constant {
        CRLF_DEFAULT => $^O eq 'MSWin32',
        HAS_UTF8_STRICT => scalar do { local $@; eval { require PerlIO::utf8_strict } },
};
 
sub _text_layers {
        my ($encoding, $crlf) = @_;
        $crlf = CRLF_DEFAULT if $crlf && $crlf eq 'auto';
 
        if (HAS_UTF8_STRICT && $encoding =~ /^utf-?8\b/i) {
                return $crlf ? ':unix:utf8_strict:crlf' : ':unix:utf8_strict';
        }
        else {
                # non-ascii compatible encodings such as UTF-16 need encoding before crlf
                return $crlf ? ":raw:encoding($encoding):crlf" : ":raw:encoding($encoding)";
        }
}
 
sub read_text {
        my ($filename, $encoding, $crlf) = @_;
        $encoding ||= 'utf-8';
        my $layer = _text_layers($encoding, $crlf);
 
        local $PerlIO::encoding::fallback = STOP_AT_PARTIAL | FB_CROAK;
        open my $fh, "<$layer", $filename or croak "Couldn't open $filename: $!";
        return do { local $/; <$fh> };
}
 
sub write_text {
        my ($filename, undef, $encoding, $crlf) = @_;
        $encoding ||= 'utf-8';
        my $layer = _text_layers($encoding, $crlf);
 
        local $PerlIO::encoding::fallback = STOP_AT_PARTIAL | FB_CROAK;
        open my $fh, ">$layer", $filename or croak "Couldn't open $filename: $!";
        print $fh $_[1] or croak "Couldn't write to $filename: $!";
        close $fh or croak "Couldn't write to $filename: $!";
        return;
}
 
sub write_binary {
        my $filename = $_[0];
        open my $fh, ">:raw", $filename or croak "Couldn't open $filename: $!";
        print $fh $_[1] or croak "Couldn't write to $filename: $!";
        close $fh or croak "Couldn't write to $filename: $!";
        return;
}
 
sub read_lines {
        my ($filename, $encoding, $crlf, $skip_chomp) = @_;
        $encoding ||= 'utf-8';
        my $layer = _text_layers($encoding, $crlf);
 
        local $PerlIO::encoding::fallback = STOP_AT_PARTIAL | FB_CROAK;
        open my $fh, "<$layer", $filename or croak "Couldn't open $filename: $!";
        return <$fh> if $skip_chomp;
        my @buf = <$fh>;
        close $fh;
        chomp @buf;
        return @buf;
}
 
sub read_dir {
        my ($dirname) = @_;
        opendir my ($dir), $dirname or croak "Could not open $dirname: $!";
        return grep { not m/ \A \.\.? \z /x } readdir $dir;
}
 
1;
 
# ABSTRACT: A simple, sane and efficient module to slurp a file
 
__END__