import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Card from 'react-bootstrap/Card';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import ListGroup from 'react-bootstrap/ListGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

import ContentEditable from './Common/ContentEditable';

class AddSentenceForm extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            sentence: '',
            nodes: []
        };
    }

    async load(sentence) {
        this.currentSentence = sentence;
        const response = await fetch('/api/dictionary/parse?includeHeadwords=true', {
            method: 'POST',
            body: sentence
        });
        if (response.ok && this.currentSentence === sentence) {
            const nodes = await response.json();
            this.setState({
                sentence,
                nodes: nodes.filter(n => !n.isBasic && n.listWords.length === 0 && n.headwords.length > 0)
            });
        }
    }

    selectNoteType(noteTyoe) {
        const fieldValues = noteType.fields.map(f => {
            return {
                fieldID: f.id,
                value: ''
            };
        });
        this.setState({ noteType, fieldValues });
    }

    async ignore(word) {
        await fetch('/api/lists/sentence/ignore', {
            method: 'PUT',
            body: JSON.stringify({
                word
            }),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        await this.load(this.currentSentence);
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

    readableFrequency(frequency) {
        switch (frequency) {
        case 'veryCommon':
            return 'Very Common';
        case 'common':
            return 'Common';
        case 'uncommon':
            return 'Uncommon';
        case 'rare':
            return 'Rare';
        case 'veryRare':
            return 'Very Rare';
        default:
            return 'Unknown';
        }
    }

    render() {
        return (
            <div {...this.props}>
                <ContentEditable value={this.currentSentence} onChange={(e) => this.load(e.target.value || '')} className='form-control h-auto text-break plaintext' />
                {this.state.nodes.length > 0 && <h5 className='mt-3 text-center'>New Words</h5>}
                {this.state.nodes.map((node, i) => {
                    return <Card className='mt-3' key={i}>
                        <Card.Header className='d-flex justify-content-between'>
                            <span className='d-flex align-self-center'>
                                <span className='align-self-center'>{node.surface}{node.surface != node.original && ` (${node.original})`}</span>
                                <Badge className={`bg-${node.frequency} align-self-center ms-1`}>{this.readableFrequency(node.frequency)}</Badge>
                            </span>
                            <Button onClick={() => this.ignore(node.original)} variant="outline-primary">
                                Ignore
                            </Button>
                        </Card.Header>
                        <ListGroup variant="flush">
                            {node.headwords.map((headword, j) => {
                                return <ListGroup.Item className='d-flex justify-content-between' key={j}>
                                    <span className='align-self-center'>{headword.headline}</span>
                                    <Button variant="secondary">
                                        Add to List
                                    </Button>
                                </ListGroup.Item>;
                            })}
                        </ListGroup>
                    </Card>;
                })}
            </div>
        );
    }
}

export default AddSentenceForm;
