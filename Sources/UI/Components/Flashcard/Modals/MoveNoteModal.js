import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

import UserContext from './../../Context/User';

class MoveNoteModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            decks: [],
            deck: null
        };
    }

    componentDidMount() {
        this.load();
    }

    componentDidUpdate(prevProps) {
        if (prevProps.note != this.props.note) {
            this.load();
        }
    }

    async load() {
        const decksResponse = await fetch('/api/flashcard/decks');
        if (decksResponse.ok) {
            const decks = await decksResponse.json();
            const selectedDeck = decks.filter(d => d.id === this.context.settings.anki.lastUsedDeckID)[0]
                || decks[0];
            this.setState({
                decks,
                deck: selectedDeck
            });
        }
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const response = await fetch(`/api/flashcard/note/${this.props.note.id}/move/${this.state.deck.id}`, {
            method: 'POST'
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            didError: result.error,
            message: result.error ? result.reason : null,
            success
        });

        if (success) {
            this.props.onSuccess();
        }
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.note} size="lg" centered>
                <Modal.Header closeButton>
                    <Modal.Title>
                        Change Deck for Note
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <InputGroup className="mb-3">
                            <Form.Control value={this.state.deck ? this.state.deck.name : '(None)'} label='Target Deck' readOnly />
                            <DropdownButton variant="outline-secondary" title="Deck" id="input-group-dropdown-1">
                                {this.state.decks.map((deck, i) => {
                                    return <Dropdown.Item key={i} active={this.state.deck && deck.id == this.state.deck.id} onSelect={() => this.setState({ deck })}>{deck.name}</Dropdown.Item>;
                                })}
                            </DropdownButton>
                        </InputGroup>

                        {this.state.didError && <Alert variant="danger" className='mb-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mb-3'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12' variant="primary" type="submit" disabled={this.state.isSubmitting || !this.state.deck}>
                            {this.state.isSubmitting ? 'Loading...' : 'Move All Cards in Note'}
                        </Button>
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

MoveNoteModal.contextType = UserContext;
export default MoveNoteModal;
