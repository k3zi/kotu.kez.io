import React from "react";

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown'
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

import ContentEditable from './../../Common/ContentEditable';

class CreateNoteModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            noteTypes: [],
            noteType: null,
            fieldValues: [],
            decks: [],
            deck: null
        };
    }

    componentDidMount() {
        this.load();
    }

    componentDidUpdate(prevProps) {
        if (prevProps.show != this.props.show) {
            this.load();
        }
    }

    async load() {
        const response = await fetch(`/api/flashcard/noteTypes`);
        const response2 = await fetch(`/api/flashcard/decks`);
        if (response.ok && response2.ok) {
            const noteTypes = await response.json();
            const selectedNoteType = noteTypes.filter(t => this.state.noteType && t.id === this.state.noteType.id)[0] || noteTypes[0];
            const fieldValues = selectedNoteType.fields.map(f => {
                return {
                    fieldID: f.id,
                    value: ''
                }
            });

            const decks = await response2.json();
            const selectedDeck = decks.filter(d => this.state.deck && d.id === this.state.deck.id)[0] || decks[0];
            this.setState({
                noteTypes,
                noteType: selectedNoteType,
                decks,
                deck: selectedDeck,
                fieldValues
            });
        }
    }

    selectNoteType(noteTyoe) {
        const fieldValues = noteType.fields.map(f => {
            return {
                fieldID: f.id,
                value: ''
            }
        });
        this.setState({ noteType, fieldValues });
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = {
            fieldValues: this.state.fieldValues,
            noteTypeID: this.state.noteType.id,
            targetDeckID: this.state.deck.id
        };
        const response = await fetch(`/api/flashcard/note`, {
            method: "POST",
            body: JSON.stringify(data),
            headers: {
                "Content-Type": "application/json"
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            didError: result.error,
            message: result.error ? result.reason : null
         });

         if (success) {
             this.props.onSuccess();
             this.setState({
                 fieldValues: this.state.noteType.fields.map(f => {
                     return {
                         fieldID: f.id,
                         value: ''
                     }
                 })
             });
         }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Create Note
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Row>
                        <Col>
                            <InputGroup className="mb-3">
                                <Form.Control value={this.state.noteType ? this.state.noteType.name : "(None)"} readOnly />
                                <DropdownButton as={InputGroup.Append} variant="outline-secondary" title="Note Type" id="input-group-dropdown-1">
                                    {this.state.noteTypes.map(noteType => {
                                        return <Dropdown.Item active={this.state.noteType && noteType.id == this.state.noteType.id} onSelect={() => this.setState({ noteType })}>{noteType.name}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                            </InputGroup>
                        </Col>
                        <Col>
                            <InputGroup className="mb-3">
                                <Form.Control value={this.state.deck ? this.state.deck.name : "(None)"} readOnly />
                                <DropdownButton as={InputGroup.Append} variant="outline-secondary" title="Deck" id="input-group-dropdown-1">
                                    {this.state.decks.map(deck => {
                                        return <Dropdown.Item active={this.state.deck && deck.id == this.state.deck.id} onSelect={() => this.setState({ deck })}>{deck.name}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                            </InputGroup>
                        </Col>
                    </Row>
                    <Form onSubmit={(e) => this.submit(e)}>
                        {this.state.noteType && this.state.noteType.fields.map((field, i) => {
                            return <Form.Group>
                                <Form.Label>{field.name}</Form.Label>
                                <ContentEditable value={this.state.fieldValues[i].value} onChange={(e) => { this.state.fieldValues[i].value = e.target.value; }} className='form-control h-auto text-break' />
                            </Form.Group>;
                        })}

                        {this.state.didError && <Alert variant="danger">
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info">
                            {this.state.message}
                        </Alert>}

                        {<Button variant="primary" type="submit" disabled={this.state.isSubmitting || !this.state.deck || !this.state.noteType}>
                            {this.state.isSubmitting ? 'Loading...' : 'Add'}
                        </Button>}
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default CreateNoteModal;
