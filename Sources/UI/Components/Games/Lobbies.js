import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';
import { withRouter } from 'react-router';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import YouTube from 'react-youtube';

import CreateOrEditModal from './../CreateOrEditModal';

class Lobbies extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateModal: null,
            metadata: {
                page: 1,
                per: 15,
                total: 0
            },
            lobbies: [],
            invites: [],
            games: [
                { name: 'Transcribe', value: 'transcribe' },
                { name: 'Pitch Accent Minimal Pairs (Perception)', value: 'pitchAccentMinimalPairsPerception' }
            ]
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch('/api/games/lobbies');
        if (response.ok) {
            const lobbies = await response.json();
            this.setState({ lobbies: lobbies.items, metadata: lobbies.metadata });
        }
    }

    showCreateModal(show) {
        this.setState({
            showCreateModal: show
        });
    }

    async join(lobby) {
        this.showCreateModal(null);
        const response = await fetch(`/api/games/lobby/${lobby.id}/join`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            return;
        }

        const result = await response.json();
        this.props.history.push(`/games/lobby/${lobby.id}/${result.id}`);
    }

    render() {
        return (
            <div>
                <h2>Game Lobbies <small className="text-muted">{this.state.metadata.total}</small><Button className='float-end' variant="primary" onClick={() => this.showCreateModal({ isPublic: true })}>Create Lobby</Button></h2>

                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th className="text-center align-middle">Name</th>
                            <th className="text-center align-middle">Game</th>
                            <th className="text-center align-middle"></th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.lobbies.map(lobby => {
                            return (<tr>
                                <td className="text-center align-middle">{lobby.name}</td>
                                <td className="text-center align-middle">{this.state.games.filter(g => g.value === lobby.game)[0].name}</td>
                                <td className="align-middle text-center">
                                    <Button className='mt-2 mt-md-0 ms-0 ms-md-2' variant="primary" onClick={() => this.join(lobby)}>Join</Button>
                                </td>
                            </tr>);
                        })}
                    </tbody>
                </Table>

                <CreateOrEditModal
                    title='Create Game'
                    fields={[
                        {
                            label: 'Name',
                            name: 'name',
                            type: 'text',
                            placeholder: 'Enter the name of the lobby'
                        },
                        {
                            label: 'Game',
                            name: 'game',
                            type: 'select',
                            placeholder: 'Select a game',
                            options: this.state.games
                        },
                        {
                            label: 'Public',
                            name: 'isPublic',
                            type: 'check'
                        }
                    ]}
                    object={this.state.showCreateModal}
                    url='/api/games/lobby'
                    method='POST'
                    onHide={() => this.showCreateModal(null)}
                    onSuccess={async (response) => this.join(await response.json())}
                />
            </div>
        );
    }
}

export default withRouter(Lobbies);
