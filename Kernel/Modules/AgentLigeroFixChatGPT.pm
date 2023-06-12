# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentLigeroFixChatGPT;

use strict;
use warnings;
use Encode qw();

use Data::Dumper;

use Kernel::System::VariableCheck qw(:all);
use JSON;
use utf8;
use vars qw($VERSION);
use Kernel::System::Ticket;
use JSON::XS;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
  my ( $Self, %Param ) = @_;

  my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
  my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
  my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
  my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
  my $TranslateObject = $Kernel::OM->Get('Kernel::Language');
  my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

  $Param{TicketID} = $ParamObject->GetParam(Param => "TicketID") || "";
  my @Articles = $Kernel::OM->Get('Kernel::System::Ticket::Article')->ArticleList(
    TicketID               => $Param{TicketID},
    OnlyFirst              => 1,                  # optional, only return first match
  );
  
 # get first ArticleID
    my $ArticleObject        = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $ArticleBackendObject = $ArticleObject->BackendForArticle(
        ArticleID => $Articles[0]->{ArticleID},
        TicketID  => $Param{TicketID}
    );

 

    # get Article and ArticleAttachement
    my %ArticleData = $ArticleBackendObject->ArticleGet(
        ArticleID     => $Articles[0]->{ArticleID},
        DynamicFields => 1,
        TicketID      => $Param{TicketID},
    );
    

	# ------------------------------------------------------------ #
	# change
	# ------------------------------------------------------------ #

  $Kernel::OM->Get('Kernel::System::Log')->Log(
          Priority => 'error',
          Message  => "Ticket ID: " . $Param{TicketID} . "\nArticle ID: " . $Articles[0]->{ArticleID} . "\n\n\n" . "Article Body: " . $ArticleData{Body} . "\n\n\n",
      );
  
my $JSON = $LayoutObject->JSONEncode(
      Data => {
        Quantity => '1'
      },
  );

  # my $JSONResult = $LayoutObject->JSONEncode(
  #     Data => {
  #       #Quantity => '13'#,
  #       OpenAI => $result
  #     },
  # );

	if ( $Self->{Subaction} eq 'GetCounter' ) {
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=utf8',
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
	}

  # return $LayoutObject->Attachment(
  #     ContentType => 'application/json; charset=utf8',
  #     Content     => $JSONResult || '',
  #     Type        => 'inline',
  #     NoCache     => 1,
  # );

if ( $Self->{Subaction} eq 'GetModal' ) {

    
  my $ua = LWP::UserAgent->new;
  
  my $LigeroFixModules = $Kernel::OM->Get('Kernel::Config')->Get('LigeroFix::Modules');
  my $ModuleConfig = $LigeroFixModules->{'061-LigeroSmartChatGPT'};



  my $chatGPTsystem = $ModuleConfig->{ChatGPTSystem} || 'Vocé é um robo que ajudará o atendente do LigeroSmart a identificar a solicitação ou problema do cliente de forma simplificada e direta limitando a menos de 250 palavras informando soluçoes por tópicos, respondendo em formato text/html';
  my $chatGPTModel = $ModuleConfig->{ChatGPTModel} || 'gpt-3.5-turbo';
  my $chatGPTKey = $ModuleConfig->{ApiKey};
  my $chatGPTMaxTokens = 300 || $ModuleConfig->{ChatGPTMaxTokens};
  my $chatGPTApiUrl = $ModuleConfig->{ApiUrl} || 'https://api.openai.com/v1/chat/completions';
  my $prompt = $ArticleData{Body};

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => "ChatGPTModel: " . Dumper($ModuleConfig) . "\n\n\n" . $chatGPTModel . "\n" . $chatGPTKey . "\n" . $chatGPTsystem . "\n" . $chatGPTMaxTokens . "\n\n\n",
    );




  # my $chat_id = 'example-chat-id';

  my @messages = (
      { 'role' => 'system', 'content' => $chatGPTsystem },
      { 'role' => 'user', 'content' => $prompt },
  );

  my $req = POST($chatGPTApiUrl,
      Content_Type => 'application/json',
      'Authorization' => "Bearer $chatGPTKey",
      Content => encode_json {
          # 'model' => 'gpt-3.5-turbo',  # Substitua pelo modelo relevante, se necessário.
          'model' => $chatGPTModel,  # Substitua pelo modelo relevante, se necessário.
          'messages' =>  \@messages,
          'max_tokens' => $chatGPTMaxTokens+0
      }
  );

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => "ChatGPTModel: " . Dumper($req) . "\n\n\n",
    );

  my $res = $ua->request($req);
  my $result = "Passamos aqui";

  if ($res->is_success) {
      my $data = decode_json($res->content);
      $result = $data->{'choices'}[0]{'message'}{'content'} || "";
  #     #print $data->{'choices'}[0]{'message'}{'content'} . "\n";
  #     # print "prompt_tokens: " . $data->{'usage'}{'prompt_tokens'} . "\n";
  #     # print "completion_tokens: " . $data->{'usage'}{'completion_tokens'} . "\n";
  #     # print "total_tokens: " . $data->{'usage'}{'total_tokens'} . "\n";
  }

  else {
      $result = $res->status_line;
  }

  return $LayoutObject->Attachment(
        ContentType => 'text/html; charset=utf8',
        Content     => $result || 'Opa tivemos um problema aqui',
        Type        => 'inline',
        NoCache     => 1,
  );

}

  return $LayoutObject->Attachment(
      ContentType => 'application/json; charset=utf8',
      Content     => $JSON || '',
      Type        => 'inline',
      NoCache     => 1,
  );

}

1;