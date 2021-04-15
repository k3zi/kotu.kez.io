import React from 'react';
import Tags from '@yaireo/tagify/dist/react.tagify';
import '@yaireo/tagify/dist/tagify.css';

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

class EditNoteModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            note: null,
            existingTags: []
        };
    }

    componentDidUpdate(prevProps) {
        if (prevProps.note != this.props.note && this.props.note) {
            this.load();
        }
    }

    async load() {
        console.log('will load');
        const response = await fetch('/api/flashcard/tags');
        let existingTags = this.state.existingTags || [];
        if (response.ok) {
            existingTags = await response.json();
        }
        this.setState({ existingTags, note: JSON.parse(JSON.stringify(this.props.note)) });
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const response = await fetch(`/api/flashcard/note/${this.state.note.id}`, {
            method: 'PUT',
            body: JSON.stringify(this.state.note),
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
                note: null
            });
        }
    }

    onTextChange(e, i) {
        this.state.note.fieldValues[i].value = e.target.value;
        this.setState({ note: this.state.note });
    }

    onTagsChange(e) {
        this.state.note.tags = e.detail.tagify.value.map(v => v.value);
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.note} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Edit Note
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    {this.state.note && <Form onSubmit={(e) => this.submit(e)}>
                         {this.state.note.noteType.fields.map((field, i) => {
                            const fieldValueIndex = this.state.note.fieldValues.findIndex(v => v.field.id === field.id);
                            if (fieldValueIndex < 0) {
                                return <div></div>;
                            }
                            return <div key={i}>
                                <Form.Group className='mt-2'>
                                    <Form.Label>{field.name}</Form.Label>
                                    <ContentEditable value={this.state.note.fieldValues[fieldValueIndex].value} onChange={(e) => this.onTextChange(e, fieldValueIndex)} className='form-control h-auto text-break plaintext clickable' />
                                </Form.Group>
                                {this.context.settings.anki.showFieldPreview && <Alert variant='secondary' className='mt-2'>
                                    <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.note.fieldValues[fieldValueIndex].value)}}></div>
                                </Alert>}
                            </div>;
                        })}
                        <Form.Group className='mt-2'>
                            <Form.Label>Tags</Form.Label>
                            <Tags settings={{ whitelist: this.state.existingTags }} defaultValue={this.state.note.tags} onChange={(e) => this.onTagsChange(e)} />
                        </Form.Group>
                        {this.state.message && <Alert variant={this.state.didError ? 'danger' : 'info'}>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12 mt-3' variant="primary" type="submit" disabled={this.state.isSubmitting || !this.state.note || this.state.note.fieldValues[0].value.trim().length == 0}>
                            {this.state.isSubmitting ? 'Loading...' : 'Update'}
                        </Button>
                    </Form>}
                </Modal.Body>
            </Modal>
        );
    }
}

EditNoteModal.contextType = UserContext;
export default EditNoteModal;
