import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import DeleteDeckModal from './Modals/DeleteDeckModal';
import CreateDeckModal from './Modals/CreateDeckModal';

class Decks extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateDeckModal: false,
            showDeleteDeckModal: null,
            decks: [],
            invites: []
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch('/api/flashcard/decks');
        if (response.ok) {
            const decks = await response.json();
            const formatter = new Intl.RelativeTimeFormat({ numeric: 'always', style: 'long' });
            for (let deck of decks) {
                const newCardsCount = deck.sm.queue.filter(i => i.repetition === -1 && (new Date(i.dueDate) < new Date())).length;
                const reviewCardsCount = deck.sm.queue.filter(i => i.repetition > -1 && (new Date(i.dueDate) < new Date())).length;
                const nextCard = deck.sm.queue[0];
                let nextCardDueData = 'N/A';
                if (nextCard) {
                    const seconds = (new Date(nextCard.dueDate) - new Date()) / 1000;
                    nextCardDueData = 'Now';
                    if (seconds > 0) {
                        const absSeconds = Math.abs(seconds);
                        const durationLookup = [
                            [1, 'second'],
                            [60, 'minute'],
                            [60 * 60, 'hour'],
                            [60 * 60 * 24, 'day'],
                            [60 * 60 * 24 * 7, 'week']
                        ];
                        let matchingLookup = durationLookup[0];
                        for (let d of durationLookup) {
                            if (d[0] < absSeconds) {
                                matchingLookup = d;
                            } else {
                                break;
                            }
                        }
                        nextCardDueData = formatter.format(Math.round(seconds / matchingLookup[0]), matchingLookup[1]);
                    }
                }
                deck.newCardsCount = newCardsCount;
                deck.reviewCardsCount = reviewCardsCount;
                deck.nextCardDueData = nextCardDueData;
            }
            this.setState({ decks });
        }
    }

    async toggleCreateDeckModal(show) {
        this.setState({
            showCreateDeckModal: show
        });
        await this.load();
    }

    async showDeleteDeckModal(deck) {
        this.setState({
            showDeleteDeckModal: deck
        });
        await this.load();
    }

    render() {
        return (
            <div>
                <h2>Anki <small className="text-muted">{this.state.decks.length} Deck(s)</small></h2>
                <Button variant="primary" onClick={() => this.toggleCreateDeckModal(true)}>Create Deck</Button>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th className="text-center">New</th>
                            <th className="text-center">To Review</th>
                            <th className="text-center">Next Due Date</th>
                            <th className="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.decks.map((deck, i) => {
                            return (<tr key={i}>
                                <td className="align-middle">{deck.name}</td>
                                <td className="align-middle text-center text-success">{deck.newCardsCount}</td>
                                <td className="align-middle text-center text-primary">{deck.reviewCardsCount}</td>
                                <td className="align-middle text-center text-primary">{deck.nextCardDueData}</td>
                                <td className="align-middle text-center">
                                    <LinkContainer to={`/flashcard/deck/${deck.id}`}>
                                        <Button variant="primary"><i className="bi bi-arrow-right"></i></Button>
                                    </LinkContainer>
                                    {' '}
                                    <Button variant="danger" onClick={() => this.showDeleteDeckModal(deck)}><i className="bi bi-trash"></i></Button>
                                </td>
                            </tr>);
                        })}
                    </tbody>
                </Table>

                <CreateDeckModal show={this.state.showCreateDeckModal} onHide={() => this.toggleCreateDeckModal(false)} onSuccess={() => this.toggleCreateDeckModal(false)} />
                <DeleteDeckModal deck={this.state.showDeleteDeckModal} didDelete={() => this.showDeleteDeckModal(null)} didCancel={() => this.showDeleteDeckModal(null)} onHide={() => this.showDeleteDeckModal(null)} />
            </div>
        );
    }
}

export default Decks;
