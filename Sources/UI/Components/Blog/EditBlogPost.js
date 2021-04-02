import _ from 'underscore';
import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import Tabs from 'react-bootstrap/Tabs';
import Tab from 'react-bootstrap/Tab';

import CreatePostModal from './Modals/CreatePostModal';
import EditPostModal from './Modals/EditPostModal';
import DeletePostModal from './Modals/DeletePostModal';

import Helpers from './../Helpers';
import UserContext from './../Context/User';
import ContentEditable from './../Common/ContentEditable';

class EditBlogPost extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeletePostModal: null,
            showEditPostModal: null,
            post: null
        };
        const self = this;
        this.throttledSave = _.throttle(() => { self.save(); }, 250);
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/blog/${this.props.match.params.id}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                post: result
            });
        }
    }

    async save() {
        if (this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true });

        const response = await fetch(`/api/blog/${this.state.post.id}`, {
            method: 'PUT',
            body: JSON.stringify(this.state.post),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
        });
    }

    async showDeletePostModal(post) {
        this.setState({
            showDeletePostModal: post
        });
        await this.load();
    }

    async showEditPostModal(post) {
        this.setState({
            showEditPostModal: post
        });
        this.load();
    }

    onTextChange(e) {
        this.state.post.content = e.target.value;
        this.throttledSave();
    }

    onChange(name, value) {
        this.state.post[name] = value;
        this.throttledSave();
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <div>
                    {this.state.post && <div>
                        <Form.Group controlId="createPostModalTitle">
                            <Form.Label>Title</Form.Label>
                            <Form.Control autoComplete="off" type="text" defaultValue={this.state.post.title} onChange={(e) => { this.onChange('title', e.target.value);}} placeholder="Enter the name of the note field" />
                        </Form.Group>

                        <Form.Group className='mt-3' controlId="createPostModalDraft">
                            <Form.Check type="checkbox" label="Mark as Draft" onChange={(e) => { this.onChange('isDraft', e.target.checked);}} defaultChecked={this.state.post.isDraft} />
                        </Form.Group>

                        <Form.Group controlId="createPostModalContent" className='mt-2'>
                            <Row>
                                <Col>
                                    <ContentEditable value={this.state.post.content} onChange={(e) => this.onTextChange(e)} className='form-control h-auto text-break plaintext clickable' />
                                </Col>
                                <Col>
                                    <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.post.content)}}></div>
                                </Col>
                            </Row>
                        </Form.Group>
                    </div>}
                    <DeletePostModal post={this.state.showDeletePostModal} didDelete={() => this.showDeletePostModal(null)} didCancel={() => this.showDeletePostModal(null)} onHide={() => this.showDeletePostModal(null)} />
                </div>
            )
            }</UserContext.Consumer>);
    }
}

export default withRouter(EditBlogPost);
