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

import ContentEditable from './../../Common/ContentEditable';
import Helpers from './../../Helpers';
import UserContext from './../../Context/User';

class CreateNoteForm extends React.Component {

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
        const response = await fetch('/api/flashcard/noteTypes');
        const response2 = await fetch('/api/flashcard/decks');
        if (response.ok && response2.ok) {
            const noteTypes = await response.json();
            const selectedNoteType = noteTypes.filter(t => this.state.noteType && t.id === this.state.noteType.id)[0]
                || noteTypes.filter(t => t.id === this.context.settings.anki.lastUsedNoteTypeID)[0]
                || noteTypes[0];
            const fieldValues = selectedNoteType ? selectedNoteType.fields.map(f => {
                const prevField = this.state.noteType && this.state.noteType.id === selectedNoteType.id && this.state.fieldValues.filter(o => o.id === f.id)[0];
                return {
                    fieldID: f.id,
                    value: (prevField ? prevField.value : '') || ''
                };
            }) : [];

            const decks = await response2.json();
            const selectedDeck = decks.filter(d => this.state.deck && d.id === this.state.deck.id)[0]
                || decks.filter(d => d.id === this.context.settings.anki.lastUsedDeckID)[0]
                || decks[0];
            this.setState({
                noteTypes,
                noteType: selectedNoteType,
                decks,
                deck: selectedDeck,
                fieldValues
            });
        }
    }

    selectNoteType(noteType) {
        const fieldValues = noteType.fields.map((f, i) => {
            return {
                fieldID: f.id,
                value: this.state.fieldValues[i] ? this.state.fieldValues[i].value : ''
            };
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
        const response = await fetch('/api/flashcard/note', {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
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
                    };
                })
            });
        }
    }

    onTextChange(e, i) {
        this.state.fieldValues[i].value = e.target.value;
        this.setState({ fieldValues: this.state.fieldValues });
    }

    render() {
        return (
            <div {...this.props}>
                <Row>
                    <Col xs={12} lg={6}>
                        <InputGroup className="mb-2">
                            <Form.Control value={this.state.noteType ? this.state.noteType.name : '(None)'} readOnly />
                            <DropdownButton variant="outline-secondary" title="Note Type" id="input-group-dropdown-1">
                                {this.state.noteTypes.map((noteType, i) => {
                                    return <Dropdown.Item key={i} active={this.state.noteType && noteType.id == this.state.noteType.id} onSelect={() => this.selectNoteType(noteType)}>{noteType.name}</Dropdown.Item>;
                                })}
                            </DropdownButton>
                        </InputGroup>
                    </Col>
                    <Col xs={12} lg={6}>
                        <InputGroup className="mt-2 mt-lg-0">
                            <Form.Control value={this.state.deck ? this.state.deck.name : '(None)'} readOnly />
                            <DropdownButton variant="outline-secondary" title="Deck" id="input-group-dropdown-1">
                                {this.state.decks.map((deck, i) => {
                                    return <Dropdown.Item key={i} active={this.state.deck && deck.id == this.state.deck.id} onSelect={() => this.setState({ deck })}>{deck.name}</Dropdown.Item>;
                                })}
                            </DropdownButton>
                        </InputGroup>
                    </Col>
                </Row>
                <Form onSubmit={(e) => this.submit(e)}>
                    {this.state.noteType && this.state.noteType.fields.map((field, i) => {
                        return <div>
                            <Form.Group key={i} className='mt-2'>
                                <Form.Label>{field.name}</Form.Label>
                                <ContentEditable value={this.state.fieldValues[i].value} onChange={(e) => this.onTextChange(e, i)} className='form-control h-auto text-break plaintext clickable' />
                            </Form.Group>
                            {this.context.settings.anki.showFieldPreview && <Alert variant='secondary' className='mt-2'>
                                <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.fieldValues[i].value)}}></div>
                            </Alert>}
                        </div>;
                    })}

                    {this.state.didError && <Alert variant="danger">
                        {this.state.message}
                    </Alert>}
                    {!this.state.didError && this.state.message && <Alert variant="info">
                        {this.state.message}
                    </Alert>}

                    <Button className='col-12 mt-3' variant="primary" type="submit" disabled={this.state.isSubmitting || !this.state.deck || !this.state.noteType || !this.state.fieldValues[0] || this.state.fieldValues[0].value.trim().length == 0}>
                        {this.state.isSubmitting ? 'Loading...' : 'Add'}
                    </Button>
                </Form>
            </div>
        );
    }
}

CreateNoteForm.contextType = UserContext;
export default CreateNoteForm;
