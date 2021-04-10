import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';
import { withRouter } from 'react-router';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import YouTube from 'react-youtube';

import Transcribe from './Transcribe';

class Lobby extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            lobby: null,
            user: null,
            ws: null,
            isReady: false
        };
    }

    componentDidMount() {
        this.setupSocket();
    }

    async setupSocket() {
        const self = this;
        const lobbyID = this.props.match.params.lobbyID;
        const connectionID = this.props.match.params.connectionID;
        const ws = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/api/games/lobby/${lobbyID}/${connectionID}/socket`);
        this.setState({ ws: ws });
        ws.onerror = (err) => {
            console.log(err);
        };

        ws.addEventListener('message', (event) => {
            const message = JSON.parse(event.data);
            const name = message.name;
            const data = message.data;
            if (name === 'update') {
                this.setState({ lobby: data.lobby, user: data.user, isReady: true });
            }
        });

        ws.onclose = () => {
            this.props.history.push(`/games`);
        };
    }

    render() {
        return (
            <div>
                {(!this.state.lobby || !this.state.isReady || !this.state.user) && <h1 className='text-center'><Spinner animation="border" variant="secondary" /></h1>}
                {this.state.lobby && this.state.user && this.state.isReady && <div>
                    <Row>
                        <Col xs={9} className='d-flex'>
                            {this.state.lobby.game === 'transcribe' && <Transcribe ws={this.state.ws} lobby={this.state.lobby} user={this.state.user} connectionID={this.props.match.params.connectionID} onPlayAudio={this.props.onPlayAudio} />}
                        </Col>
                        <Col xs={3}>
                            <h3 className='text-center'>
                                Lobby
                            </h3>

                            <ListGroup className="overflow-auto hide-scrollbar max-vh-75">
                                {this.state.lobby.users.map((user, i) => {
                                    return <ListGroup.Item className='d-flex justify-content-between' key={i}><span>{user.isOwner && <i class='bi bi-megaphone-fill pe-2'></i>}{user.name}</span><span>{user.score}</span></ListGroup.Item>;
                                })}
                            </ListGroup>
                        </Col>
                    </Row>
                </div>}
            </div>
        );
    }
}

export default withRouter(Lobby);
