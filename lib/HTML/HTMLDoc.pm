package HTML::HTMLDoc;

use 5.006;
use strict;
use warnings;
use IO::File;
use IPC::Open3 qw();
use HTML::HTMLDoc::PDF;
use vars qw(@ISA $VERSION);

@ISA = qw();
$VERSION = '0.05';
my $DEBUG = 0;

###############
# create a new Object
# param:
# return: object:HTML::HTMLDOC
###############
sub new {
	my $package = shift;

	my $self = {};
	bless($self, $package);

	while (my $key = shift) {
		my $value = shift;
		$self->{'config'}->{$key} = $value;
	}

	$self->_init();

	return $self;
}

###############
# initialises the Object with the basic parameters
# param: -
# return: -
###############
sub _init {
	my $self = shift;

	if ((not defined $self->{'config'}->{'mode'}) || ($self->{'config'}->{'mode'} ne 'file' && $self->{'config'}->{'mode'} ne 'ipc')) {
		$self->{'config'}->{'mode'} = 'ipc';
	}

	if ( (!$self->{'config'}->{'tmpdir'}) || (!-d $self->{'config'}->{'tmpdir'})) {
		$self->{'config'}->{'tmpdir'} = '/tmp';
	}

	$self->{'erros'} = [];
	$self->{'doc_config'} = {};

	$self->set_page_size('a4');
	$self->portrait();
	$self->set_charset('iso-8859-1');
	$self->_set_doc_config('quiet');
	$self->set_output_format('pdf');
}

###############
# stores a specific value for formating the outputdoc
# param: key:STRING, value:STRING
# return: 1
###############
sub _set_doc_config {
	my $self = shift;
	my $key = shift;
	my $value = shift;

	$self->{'doc_config'}->{$key} = $value;
	return 1;
}

###############
# deletes a specific config
# param: key:STRING
# return: value:STRING
###############
sub _delete_doc_config {
	my $self = shift;
	my $key = shift;
	if (exists $self->{'doc_config'}->{$key}) {
		delete $self->{'doc_config'}->{$key};
	}
}


###############
# tells a specific value for formating the outputdoc
# param: key:STRING
# return: value:STRING
###############
sub _get_doc_config {
	my $self = shift;
	my $key = shift;
	return $self->{'doc_config'}->{$key};
}

###############
# returns all the configuration keys
# param: key:STRING
# return: value:STRING
###############
sub _get_doc_config_keys {
	my $self = shift;

	my @keys = keys %{$self->{'doc_config'}};
	print STDERR "Keys: @keys\n" if $DEBUG;
	return @keys;
}

###############
# tests if the parameter exists in the array
# of allowed params
# param: key:STRING, \@allowed
# return: 1/0
###############
sub _test_params {
	my $self = shift;
	my $param = shift;
	my $allowed = shift;

	my $ok = 0;
	foreach my $aparam (@{$allowed}) {
		if ($param eq $aparam) {
			$ok=1;
			last;
		}
	}

	return 1;
}


#######################################
# 			public Methods for configuring behaviour and style of the
#			Document
#######################################

###############
# sets the size of the pages - default: a4
# param: letter, a4, WxH{in,cm,mm}
# return: 1/0
###############
sub set_page_size {
	my $self = shift;
	my $value = shift;

	if ( !$value && $value ne 'a4' && $value ne 'letter' && $value!~/^\d+x\d+(?:in|cm|mm)/ ) {
		$self->error("unknown value for pagesize: $value");
		return 0;
	}

	$self->_set_doc_config('size', $value);
    return 1;
}

sub get_page_size {
	my $self = shift;
	return $self->_get_doc_config('size');
}

###############
# sets the master-password of the doc
# param: password:STRING
# return: 1/0
###############
sub set_owner_password {
	my $self = shift;
	my $value = shift;
	$self->_set_doc_config('owner-password', $value);
	return 1;
}

###############
# sets the user-password of the doc
# param: password:STRING
# return: 1/0
###############
sub set_user_password {
	my $self = shift;
	my $value = shift;
	$self->_set_doc_config('user-password', $value);
	return 1;
}

# all,annotate,copy,modify,print,no-annotate,no-copy,no-modify,no-print,none
###############
# sets the master-password of the doc
# param: password:STRING
# return: 1/0
###############
sub set_permissions {
	my $self = shift;
	my $value = shift;

	my @allowed = ('all','annotate','copy','modify','print','no-annotate','no-copy','no-modify','no-print','none');
	# test the set value
	if ($self->_test_params(lc($value), \@allowed)) {
		# wrong permission set
		$self->error("wrong permission set: $value");
		return 0;
	}

	$self->_set_doc_config('permissions', $value);
	return 1;
}

###############
# sets the pages to landscape
# param: -
# return: 1/0
###############
sub landscape {
	my $self = shift;

	$self->_set_doc_config('landscape', '');
	$self->_delete_doc_config('portait');
	return 1;
}

###############
# sets the pages to landscape
# param: -
# return: 1/0
###############
sub portrait {
	my $self = shift;

	$self->_set_doc_config('portrait', '');
	$self->_delete_doc_config('landscape');
	return 1;
}

###############
# turns the title on
# param: -
# return: 1/0
###############
sub title {
	my $self = shift;

	$self->_set_doc_config('title', '');
	$self->_delete_doc_config('no-title');
	return 1;
}

###############
# turns the title off
# param: -
# return: 1/0
###############
sub no_title {
	my $self = shift;

	$self->_set_doc_config('no-title', '');
	$self->_delete_doc_config('title');
	return 1;
}

###############
# sets the right margin
# param: margin|NUM, messure:in,cm,mm
# return: 1/0
###############
sub set_right_margin {
	my $self = shift;
	my $margin = shift;
	my $m = shift || 'cm';
	return $self->_set_margin('right', $margin, $m);
}

###############
# sets the right margin
# param: margin|NUM, messure:in,cm,mm
# return: 1/0
###############
sub set_left_margin {
	my $self = shift;
	my $margin = shift;
	my $m = shift || 'cm';
	return $self->_set_margin('left', $margin, $m);
}

###############
# sets the bottom margin
# param: margin|NUM, messure:in,cm,mm
# return: 1/0
###############
sub set_bottom_margin {
	my $self = shift;
	my $margin = shift;
	my $m = shift || 'cm';
	return $self->_set_margin('bottom', $margin, $m);
}

###############
# sets the right margin
# param: margin|NUM, messure:in,cm,mm
# return: 1/0
###############
sub set_top_margin {
	my $self = shift;
	my $margin = shift;
	my $m = shift || 'cm';
	return $self->_set_margin('top', $margin, $m);
}


sub _set_margin {
	my $self = shift;
	my $where = shift;
	my $margin = shift;
	my $m = shift;

	# test the values
	if ( $margin!~/^\d+$/ || ( ($m ne 'in') && ($m ne 'cm') && ($m ne 'mm') )) {
		$self->error("wrong arguments for $where-margin: $margin $m");
		return 0;
	}

	$self->_set_doc_config($where, "$margin$m");
	return 1;
}

###############
# sets the color of the body
# param: color:hex
# return: 1/0
###############
sub set_bodycolor {
	my $self = shift;
	my $color = shift;
	return $self->_set_doc_config('bodycolor', $color);
}

###############
# sets the default font for the body
# param: fontface:STRING
# return: 1/0
###############
sub set_bodyfont {
	my $self = shift;
	my $font = shift;

	my @allowed = qw(Arial Courier Helvetica Monospace Sans-Serif Serif Symbol Times);
	if ( !$self->_test_params($font, \@allowed) ) {
		$self->error("illegal font set $font");
	}

	return $self->_set_doc_config('bodyfont', $font);
}

###############
# takes an image-filename that is used as background
# for all Pages
# param: image:STRING
# return: 1/0
###############
sub set_bodyimage {
	my $self = shift;
	my $image = shift;

	if ( ! -f "$image" ) {
		$self->error("Backgroundimage $image could not be found");
		return 0;
	}

	$self->_set_doc_config('bodyimage', $image);
	return 1;
}

###############
# set the witdh in px for the background image
# param: width:INT
# return: 1/0
###############
sub set_browserwidth {
	my $self = shift;
	my $width = shift;

	if ($width !~ /^\d+$/) {
		$self->error("wrong browserwidth $width set");
		return 0;
	}

	$self->_set_doc_config('browserwidth', $width);
	return 1;
}

###############
# sets the compression level
# param:
# return: 1/0
###############
sub set_compression {
	my $self = shift;
	my $comp = shift;
	return $self->_set_doc_config('compression', $comp);
}

###############
# sets the pagemode
# param: mode:[document,outline,fullscreen]
# return: 1/0
###############
sub set_pagemode {
	my $self = shift;
	my $value = shift;

	#--pagemode {document,outline,fullscreen}
	if (!$self->_test_params($value, ['document', 'outline', 'fullscreen']) ) {
    #if ($value ne 'document' && $value ne 'outline' && $value ne 'fullscreen') {
		$self->error("wrong pagemode: $value");
		return 0;
	}

	$self->_set_doc_config('pagemode', $value);
}

###############
# sets the charset
# param: charset
# return: 1/0
###############
sub set_charset {
	my $self = shift;
	my $charset = shift;

	$self->_set_doc_config('charset', $charset);
	return 1;
}

###############
# turns colors on in doc
# param: charset
# return: 1/0
###############
sub color_on {
	my $self = shift;

	$self->_set_doc_config('color', '');
	$self->_delete_doc_config('grey', '');
	return 1;
}

###############
# turns colors on in doc
# param: 
# return: 1/0
###############
sub color_off {
	my $self = shift;

	$self->_set_doc_config('grey', '');
	$self->_delete_doc_config('color', '');
	return 1;
}

###############
# turns encryption on
# param: -
# return: 1/0
###############
sub enable_encryption {
	my $self = shift;

	$self->_set_doc_config('encryption', '');
	$self->_delete_doc_config('no-enryption', '');
	return 1;
}

###############
# turns encryption on
# param: -
# return: 1/0
###############
sub disable_encryption {
	my $self = shift;

	$self->_set_doc_config('no-encryption', '');
	$self->_delete_doc_config('enryption', '');
	return 1;
}

###############
# sets the outputformat of the document
# param: format:STRING
# return: 1/0
###############
sub set_output_format {
	my $self = shift;
	my $f = shift;

	my @allowed = qw(html pdf pdf11 pdf12 pdf13 pdf14 ps ps1 ps2 ps3);
	if( !$self->_test_params($f, \@allowed)) {
		$self->error("Wrong output format set $f");
		return 0;
	}

	$self->_set_doc_config('format', $f);
	return 1;
}


####################################################
#
# 			Methods for outputting the result
#
####################################################



###############
# sets the html-page that should be rendered
# param: html:STRING
# return: 1/0
###############
sub set_html_content {
	my $self = shift;
	my $html = shift;

	$self->{'html'} = $html;
	return 1;
}

###############
# returns the html-content
# param: -
# return: html:STRING
###############
sub get_html_content {
	my $self = shift;
	return $self->{'html'};
}

###############
# private: opens a temporary file and sets the
# html-content in
# param: -
# return: filename:STRING
###############
sub _prepare_input_file {
	my $self = shift;

	my $i=0;
	my $filename;   
	while($i<1000) {
		my $randpart = int(rand(1000));
		$filename = $self->{'config'}->{'tmpdir'} . "/htmldoc$randpart.html";

		if (-f $filename) {
			$i++;
			next;
		} else {
			last;
		}
	}

	my $file = new IO::File($filename, 'w');
	if (!$file) {
		warn "could not open tempfile $!";
		return undef;
	}
	$file->print($self->get_html_content());
	$file->close();
	$self->{'config'}->{'tmpfile'} = $filename;

	return $filename;
}

###############
# private: cleans up, deletes the tempfile
# param: -
# return: -
###############
sub _cleanup {
	my $self = shift;
	unlink($self->{'config'}->{'tmpfile'});
}

###############
# finaly produces the pdf-output
# param: -
# return: pdf:STRING
###############
sub generate_pdf {
	my $self = shift;

	my $params = $self->_build_parameters();
	my $pdf;

	if ($self->{'config'}->{'mode'} eq 'ipc') {
		# we are in normale Mode, use IPC
		my ($pid, $error);
    	($pid,$pdf,$error) = $self->_run("htmldoc  $params --webpage -", $self->get_html_content() . $self->get_html_content());
	} else {
		# we are in file-mode
		my $filename = $self->_prepare_input_file();
		return undef if (!$filename);
		$pdf = `htmldoc  $params --webpage $filename`;
    	$self->_cleanup();
	}

	my $doc = new HTML::HTMLDoc::PDF(\$pdf);

	return $doc;
}

###############
# generates a string for the configuration of htmldoc
# param: -
# return: params:STRING
###############
sub _build_parameters {
	my $self = shift;

	my $paramstring='';

	foreach my $key($self->_get_doc_config_keys()) {
		my $value = $self->_get_doc_config($key) || '';
		$paramstring .= " --$key $value";
	}
	return $paramstring;
}

sub _run {
	my $self = shift;
	my $command = shift;
	my $input = shift;

	# create new Filehandles
	my ($stdin,$stdout,$stderr) = (IO::Handle->new(),IO::Handle->new(),IO::Handle->new());
	my $pid = IPC::Open3::open3($stdin,$stdout,$stderr, $command);
	if (!$pid) {
		$self->error("Cannot fork [COMMAND: '$command'].");
		return (0);
	}

	print $stdin $input;
	close $stdin;

	my $output = join('',<$stdout>);
	close $stdout;

	my $error = join('',<$stderr>);
	close $stderr;

	wait();


	if ($DEBUG) {
		print STDERR "\n********************************************************************\n";
		print STDERR "COMMAND : \n$command [PID $pid]\n";
		print STDERR "STDIN  :  \n$input\n";
		print STDERR "STDOUT :  \n$output\n";
		print STDERR "STDERR :  \n$error\n";
		print STDERR "\n********************************************************************\n";
	}

     return($pid,$output,$error);
}


###############
# set or retrieve an accured error
# param: -
# return: pdf:STRING
###############
sub error {
	my $self = shift;
	my $error = shift;

	if (defined $error) {
		push(@{$self->{'errors'}}, $error);
	} else {
		if (wantarray()) {
			return @{$self->{'errors'}};
		} else {
			return $self->{'errors'}->[0];
		}
	}
}

1;
__END__

=head1 NAME

HTML::HTMLDoc - Perl interface to the htmldoc programm for producing PDF-Files from HTML-Content

=head1 SYNOPSIS

  use HTML::HTMLDoc;

  my $htmldoc = new HTML::HTMLDoc();

  $htmldoc->set_html_content(qq~<html><body>A PDF file</body></html>~);

  my $pdf = $htmldoc->generate_pdf();

  print $pdf->to_string();
  $pdf->to_file('foo.pdf');



=head1 DESCRIPTION

This Module provides an OO-interface to the htmldoc programm.

You can use it to produce PDF or PS files from a HTML-document. Currently many but not all
parameters of HTMLDoc are supported.

You need to have HTMLDoc installed before installing this module.

All the pdf-Methods return true for success or false for failure. You can test if errors 
accured by calling the error-method.

Normaly this module uses IPC::Open3 for communacation with the HTMLDOC process. However,
in mod_perl-environments there appear problems with this module because the standard-output can not
be captured. For this problem this module provides a fix doing the communication in file-mode.

For this you can specify the parameter mode in the constructor:
my $htmldoc = new HTMLDoc('mode'=>'file', 'tmpdir'=>'/tmp');




=head1 METHODS

=head2 new()

creates a new Instance of HTML::HTMLDoc.

Optional parameters are:
mode=>['file'|'ipc'] defaults to ipc
tmpdir=>$dir defaults to /tmp

The tmpdir is used for temporary html-files in filemode. Remember to set the file-permissions
to write for the executing process.


=head2 set_page_size($size)

sets the desired size of the pages in the resulting PDF-document. $size is one of:

=over 4

=item *
a4 (default)

=item *
letter

=item *
WxH{in,cm,mm} eg '10x10cm'

=back       


=head2 set_owner_password($password)

sets the owner-password for this document. $password can be any string. This only has effect if encryption is enabled.
see enable_encryption().


=head2 set_user_password($password)

sets the user-password for this document. $password can be any string. If set, User will be asked for this
password when opening the file. This only has effect if encryption is enabled, see enable_encryption().


=head2 set_permissions($perm)

sets the permissions the user has to this document. $perm can be:

=over 4

=item *
all

=item *
annotate

=item *
copy

=item *
modify

=item *
print

=item *
no-annotate

=item *
no-copy

=item *
no-modify

=item *
no-print

=item *
none

=back



=head2 landscape()

sets the format of the resulting pages to landscape


=head2 portait()

sets the format of the resulting pages to portrait


=head2 title()

turns the title on.


=head2 no_title()

turns the title off.


=head2 set_right_margin($margin, $messure)

set the right margin. $margin is a INT, $messure one of 'in', 'cm' or 'mm'.


=head2 set_left_margin($margin, $messure)

set the left margin. $margin is a INT, $messure one of 'in', 'cm' or 'mm'.


=head2 set_bottom_margin($margin, $messure)

set the bottom margin. $margin is a INT, $messure one of 'in', 'cm' or 'mm'.


=head2 set_top_margin($margin, $messure)

set the top margin. $margin is a INT, $messure one of 'in', 'cm' or 'mm'.


=head2 set_bodycolor($color)

Sets the background of all pages to this background color. $color is a hex-coded color-value (eg. #FFFFFF).


=head2 set_bodyfont($font)

Sets the default font of the content. Currently the following fonts are supported:  

Arial Courier Helvetica Monospace Sans-Serif Serif Symbol Times


=head2 set_bodyimage($image)

Sets the background image for the document. $image is the path to the image in your filesystem.
                      

=head2 set_browserwidth($width)

specifies the browser width in pixels. The browser width is used to scale images and pixel measurements when generating PostScript and PDF files. It does not affect the font size of text.

The default browser width is 680 pixels which corresponds roughly to a 96 DPI display. Please note that your images and table sizes are equal to or smaller than the browser width, or your output will overlap or truncate in places.
         

=head2 set_compression($level)

specifies that Flate compression should be performed on the output file. The optional level parameter is a number from 1 (fastest and least amount of compression) to 9 (slowest and most amount of compression).

This option is only available when generating Level 3 PostScript or PDF files.


=head2 set_pagemode($mode)

specifies the initial viewing mode of the document. $mode is one of:

=over 4

=item * 
document - the document pages are displayed in a normal window

=item *
outline - the document outline and pages are displayed

=item *
fullscreen - the document pages are displayed on the entire screen

=back

   
=head2 set_charset($charset)

defines the charset for the output document. The following charsets are currenty supported:
cp-874 cp-1250 cp-1251 cp-1252 cp-1253 cp-1254 cp-1255 cp-1256 cp-1257 cp-1258
iso-8859-1 iso-8859-2 iso-8859-3  iso-8859-4 iso-8859-5 iso-8859-6 iso-8859-7 
iso-8859-8 iso-8859-9 iso-8859-14 iso-8859-15 koi8-r
                                    

=head2 color_on()

defines that color output is desired


=head2 color_off()

defines that b&w output is desired


=head2 enable_encryption()

enables encryption and security features for the document.


=head2 disable_encryption()

enables encryption and security features for the document.


=head2 set_output_format($format)

sets the format of the output-document. $format can be one of:

=over 4

=item *
html

=item *
pdf (default)

=item *
pdf11

=item *
pdf12

=item *
pdf13

=item *
pdf14

=item *
ps

=item *
ps1

=item *
ps2

=item *
ps3

=back


=head2 set_html_content($html)

this is the function to set the html-content as a scalar.


=head2 get_html_content()

gives back the previous set html-content.


=head2 generate_pdf()

generates the output-document. Returns a instance of HTML::HTMLDoc::PDF. See the perldoc of this class
for details


=head2 error()

in scalar content returns the last error that occured, in list context returns all errors that accured.


=head2 EXPORT

None by default.


=head1 AUTHOR

Michael Frankl - mfrankl@seibert-media.de

=head1 SEE ALSO

L<perl>.

L<HTML::HTMLDoc::PDF>.

=cut
