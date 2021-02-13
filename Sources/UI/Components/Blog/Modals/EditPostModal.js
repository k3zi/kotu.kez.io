import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';
import Tabs from 'react-bootstrap/Tabs';
import Tab from 'react-bootstrap/Tab';

import Helpers from './../../Helpers';
import ContentEditable from './../../Common/ContentEditable';

class EditPostModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            content: ''
        };
    }

    componentDidUpdate(prevProps) {
        if (this.props.post && this.props.post != prevProps.post) {
            this.setState({ content: this.props.post.content });
        }
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        data.content = this.state.content;
        data.tags = [];
        data.isDraft = !!data.isDraft;
        const response = await fetch(`/api/blog/${this.props.post.id}`, {
            method: 'PUT',
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
            message: result.error ? result.reason : null,
            success
        });

        if (success) {
            this.props.onSuccess();
            this.setState({
                success: false,
                message: null,
                didError: false
            });
        }
    }

    onTextChange(e) {
        this.setState({ content: e.target.value || '' });
    }

    render() {
        return (
            <Modal {...this.props} show={this.props.post != null} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Edit Post
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    {this.props.post && <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="createPostModalTitle">
                            <Form.Label>Title</Form.Label>
                            <Form.Control autoComplete="off" type="text" name="title" defaultValue={this.props.post.title} placeholder="Enter the name of the note field" />
                        </Form.Group>

                        <Form.Group className='mt-3' controlId="createPostModalDraft">
                            <Form.Check type="checkbox" label="Mark as Draft" name='isDraft' defaultChecked={this.props.post.isDraft} />
                        </Form.Group>

                        <Form.Group controlId="createPostModalContent" className='mt-2'>
                            <Tabs defaultActiveKey="content" id="editPostModalTabs" onSelect={() => this.setState({ state: this.state })}>
                                <Tab eventKey="content" title="Content" className='mt-1'>
                                    <ContentEditable value={this.state.content} onChange={(e) => this.onTextChange(e)} className='form-control h-auto text-break plaintext' />
                                </Tab>
                                <Tab eventKey="preview" title="Preview" className='mt-1'>
                                    <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.content)}}></div>
                                </Tab>
                            </Tabs>
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger" className='mt-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mt-3'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12 mt-3' variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Loading...' : 'Save'}
                        </Button>
                    </Form>}
                </Modal.Body>
            </Modal>
        );
    }
}

export default EditPostModal;
