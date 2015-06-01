#!/usr/bin/perl
# Automated Lynch Processing, Handling & Analysis

use strict;
use warnings;

use LWP::Simple;
use HTML::TreeBuilder;
use HTML::Element;

# New game set players, playeraliases & threadid
# Update daystartpost to post number of night time narrative and comment out dead players for each new day
my $site="http://forums.macrumors.com/";
# Thread ID (t=X from the forum thread URL)
my $threadid=1884930;
# Post number of the day start narrative post, vote counting will start with the post after this
my $daystartpost=87;
# Majority Lock Votes - leave this alone as it is calculated from players.
my $majoritylock=1;

# Don't change these
my $urlbase="$site/threads/$threadid";
my $daystartpage=int($daystartpost/25)+1;

# List of players
my @players = (
'rick snagwell',
'Sythas',
'Moyank24',
'Scepticalscribe', 
'Don\'t panic',
'Plutonius',
'Koodauw',
'chrmjenkins',
'Melrose',
'anjinha',
'Queen of Spades',
'ravenvii',
'Comeagain?',
'TechGod',
'FenrisMoonlight',
'Intell',
'Tomorrow',
'WoodNUFC',
'Astroboy907',
#'twietee', 
#'jimN',
#'costabunny', 
#'Roric',
#'ucfgrad93',
#'philbeeney',
#'jav6454',
'no vote'
);

# Common aliases and used misspellings for players
my %playeraliases = (
'moyank' => 'Moyank24',
'rick' => 'rick snagwell',
'dont panic' => 'Don\'t panic',
'dp' => 'Don\'t panic',
'qos' => 'Queen of Spades',
'fireshot' => 'fireshot91',
'jav' => 'jav6454',
'fenris' => 'FenrisMoonlight',
'fenris moonlight' => 'FenrisMoonlight',
'pluto' => 'Plutonius',
'appleguy' => 'appleguy123',
'applguy123' => 'appleguy123',
'benjy' => 'Benjy91',
'woodunfc' => 'WoodNUFC',
'plutonious'=>'Plutonius',
'ufcgrad93'=>'ucfgrad93',
'skepticalscribe'=>'Scepticalscribe',
'astroboy' => 'Astroboy907',
'comeagain' => 'Comeagain?',
'comegain' => 'Comeagain?',
'no-vote' => 'no vote'
);

# Nothing below here should need changing for game config

my $playerAliasSearch;
my %voters = ();
my $votinglog;
my %votinglist = ();
my $maxvotes = 0;
my $tiebreak = undef;

sub displayVotes {
	my $totalvotes = 0;
	print "[U]Potential Wolves[/U]\n";
	# First, the tiebreak winner
	if(defined($tiebreak)) {
		print "[COLOR=\"Red\"]$tiebreak: " .scalar(@{$votinglist{$tiebreak}}) . " ", join(", ", @{$votinglist{$tiebreak}}), "[/COLOR]\n";
		$totalvotes = scalar(@{$votinglist{$tiebreak}});
		# Delete the tiebreak winner so we don't output twice
		delete $votinglist{$tiebreak};
	}
	# Order the rest of the votes by number of votes.
	for my $votee ( sort { @{$votinglist{$b}} <=> @{$votinglist{$a}} } keys %votinglist ) {
		print "$votee: " . scalar(@{$votinglist{$votee}}) . " ", join(", ", @{$votinglist{$votee}}), "\n";
		$totalvotes += scalar(@{$votinglist{$votee}});
	}
	# Display players that haven't voted yet
	if($totalvotes < scalar(@players)-1) {
		print "\nYet to vote: ";
		for my $i (0 .. scalar(@players)-2) {
			if(!defined($voters{$players[$i]})) {
				print $players[$i] . ", ";
				$totalvotes++;
			}
		}
	}
	
	print "\n\n";
	if($totalvotes != scalar(@players)-1) {
		print "Warning TotalVotes: $totalvotes/" . (scalar(@players)-1) . "\n\n";
	}
}

sub calcTiebreak {	
	# Reset max votes & tiebreak
	$maxvotes = 0;
	$tiebreak = undef;
	my $lastvote = 0;
	
	for my $votee (keys %votinglist) {
		my $votes = scalar(@{$votinglist{$votee}});
		my $voter = $votinglist{$votee}[$votes-1];
		# if we have more votes than last votes, move to tiebreak holder
		if($votes > $maxvotes) {
			$maxvotes = $votes;
			$lastvote = $voters{$voter}{'post'};
			$tiebreak = $votee;
		} elsif($votes == $maxvotes) {
			if($voters{$voter}{'post'} > $lastvote) {
				$lastvote = $voters{$voter}{'post'};
				$tiebreak = $votee;
			}
		}
	}
}

sub updateVoteCount
{	

	(my $voter, my $votee, my $postnum, my $posturl) = @_;
	
	#print "updateVote Count $voter $votee $postnum $posturl\n";
	
	# Create tmp string to add to voting log
	$votee = $playeraliases{lc $votee};
	my $votinglogtmp = "Post [URL=\"" . $posturl . "\"]" . $postnum . "[/URL] ". $voter . " voted for " . $votee ;
	if(defined($voters{$voter})) {
		# If this player already voted, delete previous vote
		$votinglogtmp .= " replacing previous vote in post " . $voters{$voter}{'post'} . " for " . $voters{$voter}{'votee'}; 
	}
	# If we previously reached majority lock, no longer count votes
	if($maxvotes >= $majoritylock) {
		# Add to voting log in silver
		$votinglog .= "[COLOR=\"Silver\"]" . $votinglogtmp . "[/COLOR]\n";
		return;
	}
	# Start by finding and removing any existing vote by $voter
	if(defined($voters{$voter})) {
		# If this player already voted, delete previous vote
		my $prevvotee = $voters{$voter}{'votee'};
		if(scalar(@{$votinglist{$prevvotee}}) == 1) {
			delete $votinglist{$prevvotee};
		} else {
			@{$votinglist{$prevvotee}} = grep !/$voter/, @{$votinglist{$prevvotee}};
		}
		# If tiebreak holder
		if($prevvotee eq $tiebreak) {
			$maxvotes = 0;
			calcTiebreak;
			# Loop through votes
		}
	}
	# Update voters list (hashed by voter name)
	$voters{$voter}{'votee'} = $votee;
	$voters{$voter}{'post'} = $postnum;
	
	# Add new vote to list
	if(! $votinglist{$votee}) {
    	$votinglist{$votee} = [$voter];
    } else {
 	   push @{$votinglist{$votee}}, $voter;
 	}
 	
 	if(scalar(@{$votinglist{$votee}}) > $maxvotes) {
 		$maxvotes = scalar(@{$votinglist{$votee}});
 		$tiebreak = $votee;
 		if($maxvotes == $majoritylock) {
 			$votinglogtmp = "[COLOR=\"Red\"][i]" . $votinglogtmp . " majority lock![/i][/COLOR]";
			print "[COLOR=\"Red\"][i]Majority Lock reached: Post: " . $postnum . " " . $voter . " majority locked " . $votee . "[/i][/COLOR]\n\n";
 		}
 	}
 	$votinglog .= $votinglogtmp . "\n";
}

sub processPage
{
	my $page = $_[0];
	my $currentpost = $_[1];
	
	# Get the page content
	my $content = get($page);
	# Parse it into a HTML Tree
	my $tree = HTML::TreeBuilder->new;
	$tree->parse_content($content);
		
	# Get post numbers, posters and the post content as arrays.
	my @postnums = $tree->look_down('_tag' => 'a', 'class' => 'item muted postNumber hashPermalink OverlayTrigger');
	my @posters = $tree->look_down('_tag' => 'a', 'class' => 'username author');
	my @post = $tree->look_down('_tag' => 'div', 'class' => 'messageContent');
	#'id' => qr/post_message_/);

	# Give up if the three arrays are different sizes, as something must have gone wrong	
	if(scalar(@postnums) != scalar(@posters) || scalar(@postnums) != scalar(@post)) {
		die "Wrong number of entries found! " . scalar(@postnums) . ":" . scalar(@posters) . ":" . scalar(@post);
	}
	
	# Exit if we didn't find any posts
	my $totalposts = scalar(@postnums);
	if($totalposts == 0) {
		print "No posts found?!";
		return 0;
	}
	
	# Loop through each post
PostLoop:
	foreach my $i (0 .. $totalposts-1) {
		my $postnum = $postnums[$i]->as_text();
		$postnum =~ s/#//;
		# Process if post number is higher than current (last processed) post
		#print "Processing post $postnum";
		if($postnum > $currentpost) {
			$currentpost = $postnum;
			my $voter = $posters[$i]->as_text();
			# Confirm poster in players list
			if(scalar(grep{/$voter/i} @players) != 1) {
				print "Post $postnum: Ignoring post by non player! $voter\n";
				next PostLoop;
			}

			# Find any blockquote (quoted posts) and delete them
			my @blockquotes = $post[$i]->look_down('_tag' => 'blockquote', class => 'quoteContainer');
			foreach my $blockquote (@blockquotes) {
				$blockquote->delete();
			}
			# Get any bolded content
			my @bold = $post[$i]->look_down('_tag' => 'b');
			# Ignore post if more than 1 thing bolded.
			# TODO: Should this search all bolded content for a vote?
			# 24/07/2012 - Modified to check all bolded content and keep last bolded player name
			#if($postnum == 621) {
			#	print $post[$i]->as_HTML(). "\n";
			#}
			if(scalar(@bold) == 0) {
				next PostLoop;
			}
			my $boldedtext="";
			foreach my $b (0 .. scalar(@bold)-1) {
				$boldedtext .= $bold[$b]->as_text();
			}
			
			my @matches = ($boldedtext =~ m/$playerAliasSearch/gi);
			
			if(scalar(@matches == 0)) {
				print "Post $postnum: No vote found in bolded text - missing alias? '";
				print $boldedtext . "' " . $voter . "." . $postnum . "\n";
			} else {
				my $votee = undef;
				foreach my $b (0 .. scalar(@matches)-1) {
				#if(scalar(@bold) == 1) {		
					# If bolded text is in playeraliases (use lowercase for hash look up into lower cased playeraliases list)
					# This now has to be true since its the result of a regexp match but left here for sanity
					if($playeraliases{lc $matches[$b]}) {
						$votee = $matches[$b];
					}
				}

				if($playeraliases{lc $votee}) {
					# Update voting log
					my $posturl = $site . $postnums[$i]->attr("href");
					updateVoteCount($voter, $votee, $postnum, $posturl);
				} else {
					print "Post $postnum: Vote for unknown player found - missing alias? -- ";
					print $votee . "(" . lc $votee . ") " . $voter . "." . $postnum . "\n";
				}
			}
		}		
	#	print $post[$i]->as_text() . "\n";
	#	print $post[$i]->as_HTML() . "\n";
	}
	return $currentpost;
}

# add lower cases for all players to player aliases
foreach my $i (0 .. scalar(@players)-1) {
	my $pa = lc $players[$i];
	#print 'Aliasing' . $pa . ' to ' . $players[$i] . "\n";
	$playeraliases{$pa} = $players[$i];	
}

# and setup playerAliasSearch
$playerAliasSearch = join("|", sort(keys %playeraliases));

#print $playerAliasSearch;

$votinglog = "[U]Votes[/U]\n";
# Process each page to strip out the votes, only keeps the last vote for each player
my $page = $daystartpage;
my $post = $daystartpost;
my $lastpostprocessed = $daystartpost;
my $processpages = 1;
my $alive = scalar @players - 1;
$majoritylock = int($alive/2) + 1;

print "There are $alive possible wolves still living, so a majority of $majoritylock will send a neck to the chopping block\n";

do {
	$post = $lastpostprocessed;
	my $urlpage=$urlbase . "/page-" . $page;
	#print "Processing page " .$page . " " . $urlpage . "\n";
	$lastpostprocessed = processPage($urlpage, $post);
	$page++;
} while($lastpostprocessed > $post);

# Display the votes
displayVotes();

# Display the stored voting log
print $votinglog;
