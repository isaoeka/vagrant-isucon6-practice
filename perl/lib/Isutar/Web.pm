package Isutar::Web;
use strict;
use warnings;
use Kossy;
use DBIx::Sunny;
use Furl;
use URI::Escape qw/uri_escape_utf8/;

sub isutar_dbh {
    my ($self) = @_;
    return $self->{isutar_dbh} //= DBIx::Sunny->connect(
        $ENV{ISUTAR_DSN} // 'dbi:mysql:db=isutar', $ENV{ISUTAR_DB_USER} // 'root', $ENV{ISUTAR_DB_PASSWORD} // '', {
            Callbacks => {
                connected => sub {
                    my $isutar_dbh = shift;
                    $isutar_dbh->do(q[SET SESSION sql_mode='TRADITIONAL,NO_AUTO_VALUE_ON_ZERO,ONLY_FULL_GROUP_BY']);
                    $isutar_dbh->do('SET NAMES utf8mb4');
                    return;
                },
            },
        },
    );
}

get '/stars' => sub {
    my ($self, $c) = @_;

    my $stars = $self->isutar_dbh->select_all(q[
        SELECT * FROM star WHERE keyword = ?
    ], $c->req->parameters->{keyword});

    $c->render_json({
        stars => $stars,
    });
};

post '/stars' => sub {
    my ($self, $c) = @_;
    my $keyword = $c->req->parameters->{keyword};

    my $origin = $ENV{ISUDA_ORIGIN} // 'http://localhost:5000';
    my $url = "$origin/keyword/" . uri_escape_utf8($keyword);
    my $res = Furl->new->get($url);
    unless ($res->is_success) {
        $c->halt(404);
    }

    $self->isutar_dbh->query(q[
        INSERT INTO star (keyword, user_name, created_at)
        VALUES (?, ?, NOW())
    ], $keyword, $c->req->parameters->{user});

    $c->render_json({
        result => 'ok',
    });
};

1;
